#!/usr/bin/env bash
# uninstall.sh — Uninstall skill-hub, restore all skills
# Usage: ./uninstall.sh [--non-interactive] [--delete-repo]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"

NON_INTERACTIVE=false
DELETE_REPO=false

while [ $# -gt 0 ]; do
    case "$1" in
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --delete-repo) DELETE_REPO=true; shift ;;
        *) shift ;;
    esac
done

echo "=== Skill-Hub Uninstaller ==="
echo ""

[ -f "$CONF_FILE" ] && source "$CONF_FILE"

# ── 1. Remove cron ────────────────────────────────────────────

remove_cron() {
    crontab -l 2>/dev/null | grep -v 'skill-sync' | crontab -
    echo "  ✅ 自动同步已移除"
}

# ── 2. Restore symlinks to real directories ────────────────────

restore_symlinks() {
    local fw_str="${FRAMEWORKS:-}"
    [ -z "$fw_str" ] && return

    local IFS=','
    local restored=0

    for fw_entry in $fw_str; do
        local fw_path="${fw_entry#*:}"
        fw_path="${fw_path/#\~/$HOME}"
        [ -d "$fw_path" ] || continue

        for link in "$fw_path"/*/; do
            [ -L "${link%/}" ] || continue
            local target
            target=$(readlink "${link%/}")

            # Only restore skill-hub symlinks
            [[ "$target" != "$HUB_DIR/"* ]] && continue

            local name
            name=$(basename "${link%/}")

            # Copy content back
            rm "${link%/}"
            if [ -d "$target" ]; then
                cp -a "$target" "${link%/}"
                ((restored++)) || true
            fi
        done
    done

    echo "  ✅ $restored 个 skill 已还原为真实目录"
}

# ── 3. Remove CLAUDE.md injection ──────────────────────────────

remove_claude_md() {
    local claude_md="$HOME/.claude/CLAUDE.md"
    [ -f "$claude_md" ] || return

    # Use a temp file approach for macOS compatibility
    if grep -q 'SKILL-HUB:START' "$claude_md"; then
        sed '/SKILL-HUB:START/,/SKILL-HUB:END/d' "$claude_md" > "${claude_md}.tmp"
        mv "${claude_md}.tmp" "$claude_md"
        echo "  ✅ CLAUDE.md 已清理"
    fi
}

# ── 4. Optionally delete repo ─────────────────────────────────

delete_repo() {
    if $DELETE_REPO; then
        rm -rf "$HUB_DIR"
        echo "  ✅ skill-hub 仓库已删除"
    else
        echo "  ℹ️  仓库保留在: $HUB_DIR"
        echo "     手动删除: rm -rf $HUB_DIR"
    fi
}

# ── Main ───────────────────────────────────────────────────────

main() {
    if ! $NON_INTERACTIVE; then
        read -p "确认卸载 skill-hub? [y/N] " confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "取消" && exit 0

        read -p "删除 skill-hub 仓库 ($HUB_DIR)? [y/N] " del
        [ "$del" = "y" ] || [ "$del" = "Y" ] && DELETE_REPO=true
    fi

    remove_cron
    restore_symlinks
    remove_claude_md
    delete_repo

    echo ""
    echo "✅ 卸载完成"
}

main
