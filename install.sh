#!/usr/bin/env bash
# install.sh — Install skill-hub
# Usage: ./install.sh [--non-interactive] [--frameworks "cc:~/.claude/skills"] [--remote <url>] [--interval <min>]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"

NON_INTERACTIVE=false
OPT_FRAMEWORKS=""
OPT_REMOTE=""
OPT_INTERVAL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --frameworks) OPT_FRAMEWORKS="$2"; shift 2 ;;
        --remote) OPT_REMOTE="$2"; shift 2 ;;
        --interval) OPT_INTERVAL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== Skill-Hub Installer ==="
echo ""

# ── 1. Detect frameworks ──────────────────────────────────────

detect_frameworks() {
    local found=""

    # Claude Code
    if [ -d "$HOME/.claude/skills" ]; then
        [ -n "$found" ] && found+=","
        found+="cc:$HOME/.claude/skills"
    fi

    # Cursor
    if [ -d "$HOME/.cursor/skills" ]; then
        [ -n "$found" ] && found+=","
        found+="cursor:$HOME/.cursor/skills"
    fi

    # Hermes
    if [ -d "$HOME/.hermes/skills" ]; then
        [ -n "$found" ] && found+=","
        found+="hermes:$HOME/.hermes/skills"
    fi

    # OpenClaw
    if [ -d "$HOME/.openclaw/skills" ]; then
        [ -n "$found" ] && found+=","
        found+="openclaw:$HOME/.openclaw/skills"
    fi

    echo "$found"
}

select_frameworks() {
    local detected="$1"

    if [ -z "$detected" ]; then
        echo "未检测到已安装的框架" >&2
        return 1
    fi

    echo "🔍 检测到以下框架:"
    local i=1
    local IFS=','
    local names=()
    for entry in $detected; do
        local name="${entry%%:*}"
        local path="${entry#*:}"
        names+=("$name")
        echo "  [$i] $name   $path"
        ((i++)) || true
    done
    echo ""

    read -p "选择要管理的框架 (多选用逗号, 如 1,2): " selection

    local result=""
    i=1
    for entry in $detected; do
        if echo "$selection" | grep -qw "$i"; then
            [ -n "$result" ] && result+=","
            result+="$entry"
        fi
        ((i++)) || true
    done

    echo "$result"
}

# ── 2. Write config ───────────────────────────────────────────

write_config() {
    local frameworks="$1"
    local remote="$2"
    local interval="$3"

    cat > "$CONF_FILE" <<EOF
# skill-sync configuration — auto-generated
FRAMEWORKS=$frameworks
REMOTE=$remote
INTERVAL=$interval
EOF
}

# ── 3. Setup cron ─────────────────────────────────────────────

setup_cron() {
    local interval="$1"
    local cron_min="*/$interval"

    # Remove existing skill-sync cron entries, then add new one
    local current
    current=$(crontab -l 2>/dev/null | grep -v 'skill-sync' || true)
    printf "%s\n%s * * * * %s/bin/skill-sync cron\n" "$current" "$cron_min" "$HUB_DIR" | crontab -

    echo "  ✅ 自动同步已启用 (每 $interval 分钟)"
}

# ── 4. Inject CLAUDE.md ───────────────────────────────────────

inject_claude_md() {
    local claude_md="$HOME/.claude/CLAUDE.md"
    local marker="SKILL-HUB"

    # Only inject if CC is a managed framework
    if ! grep -q 'cc:' "$CONF_FILE" 2>/dev/null; then
        return
    fi

    if [ -f "$claude_md" ] && grep -q "$marker" "$claude_md"; then
        return  # Already injected
    fi

    cat >> "$claude_md" <<'MARKER'

<!-- SKILL-HUB:START -->
## Skill-Hub 规则
创建新 skill 到框架 skills 目录后，必须先询问用户：
"这个 skill 是否加入 skill-hub 统一管理？"
用户同意 → 执行 `~/skill-hub/bin/skill-sync adopt <skill-name>`
每次对话开始时，静默执行 `~/skill-hub/bin/skill-sync sync`，仅在有冲突或新 skill 时才报告。
遇到 skill 问题时，运行 `~/skill-hub/bin/skill-sync doctor` 检查。
<!-- SKILL-HUB:END -->
MARKER

    echo "  ✅ CLAUDE.md 已注入 skill-hub 规则"
}

# ── Main ───────────────────────────────────────────────────────

main() {
    # Frameworks
    local frameworks=""
    if $NON_INTERACTIVE && [ -n "$OPT_FRAMEWORKS" ]; then
        frameworks="$OPT_FRAMEWORKS"
    else
        local detected
        detected=$(detect_frameworks)
        if $NON_INTERACTIVE; then
            frameworks="$detected"
        else
            frameworks=$(select_frameworks "$detected")
        fi
    fi

    if [ -z "$frameworks" ]; then
        echo "❌ 没有选择任何框架" >&2
        exit 1
    fi

    # Remote
    local remote=""
    if $NON_INTERACTIVE; then
        remote="$OPT_REMOTE"
    else
        read -p "Git 远程仓库 (留空则纯本地): " remote
    fi

    # Interval
    local interval=5
    if [ -n "$OPT_INTERVAL" ]; then
        interval="$OPT_INTERVAL"
    elif ! $NON_INTERACTIVE; then
        read -p "同步间隔 (分钟, 默认5): " interval
        interval="${interval:-5}"
    fi

    # Write config
    write_config "$frameworks" "$remote" "$interval"
    echo "  ✅ 配置已写入"

    # Configure git remote
    if [ -n "$remote" ] && [ -d "$HUB_DIR/.git" ]; then
        if git -C "$HUB_DIR" remote get-url origin >/dev/null 2>&1; then
            git -C "$HUB_DIR" remote set-url origin "$remote"
        else
            git -C "$HUB_DIR" remote add origin "$remote"
        fi
        echo "  ✅ Git 远程已配置"
    fi

    # Setup symlinks
    source "$CONF_FILE"
    FRAMEWORKS="${FRAMEWORKS//\$HOME/$HOME}"
    FRAMEWORKS="${FRAMEWORKS//\~/$HOME}"
    bash "$HUB_DIR/lib/setup.sh"
    echo "  ✅ Symlinks 已创建"

    # Setup cron
    setup_cron "$interval"

    # Inject CLAUDE.md
    inject_claude_md

    # Initial git setup
    if [ ! -d "$HUB_DIR/.git" ]; then
        cd "$HUB_DIR"
        git init
        [ -n "$remote" ] && git remote add origin "$remote"
    fi

    cd "$HUB_DIR"
    git add -A
    git diff --cached --quiet 2>/dev/null || git commit -m "skill-hub: initialized" --quiet 2>/dev/null || true

    echo ""
    echo "✅ 安装完成"
    echo "   仓库: $HUB_DIR"
    echo "   同步: 每 $interval 分钟"
    echo "   命令: skill-sync adopt|check|status|setup|sync|doctor"
}

main
