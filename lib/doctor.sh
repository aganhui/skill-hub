#!/usr/bin/env bash
# doctor.sh — Health check for symlinks, cron, git, config
# Usage: skill-sync doctor [--json] [--fix]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
STATE_FILE="$HUB_DIR/.sync-state.json"

JSON_OUTPUT=false
FIX_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        --fix) FIX_MODE=true ;;
    esac
done

[ -f "$CONF_FILE" ] && source "$CONF_FILE"
# Expand $HOME and ~ in FRAMEWORKS
FRAMEWORKS="${FRAMEWORKS//$HOME/$HOME}"
FRAMEWORKS="${FRAMEWORKS//~/$HOME}"
check_symlinks() {
    local broken=0
    local fixed=0
    local fw_str="${FRAMEWORKS:-}"
    local IFS=','

    for fw_entry in $fw_str; do
        local fw_name="${fw_entry%%:*}"
        local fw_path="${fw_entry#*:}"
        fw_path="${fw_path/#\~/$HOME}"

        [ -d "$fw_path" ] || continue

        for link in "$fw_path"/*/; do
            [ -L "${link%/}" ] || continue
            local target
            target=$(readlink "${link%/}")

            # Only check skill-hub symlinks
            [[ "$target" != "$HUB_DIR/"* ]] && continue

            if [ ! -d "$target" ]; then
                ((broken++)) || true
                if $FIX_MODE; then
                    rm "${link%/}"
                    ((fixed++)) || true
                else
                    echo "  🔗 断裂: ${link%/} → $target"
                fi
            fi
        done
    done

    echo "$broken:$fixed"
}

check_cron() {
    if crontab -l 2>/dev/null | grep -q 'skill-sync'; then
        echo "ok"
    else
        echo "missing"
    fi
}

check_git() {
    if [ ! -d "$HUB_DIR/.git" ]; then
        echo "not_git_repo"
        return
    fi

    if git -C "$HUB_DIR" remote get-url origin >/dev/null 2>&1; then
        # Check if remote is reachable (with timeout)
        if git -C "$HUB_DIR" ls-remote --heads origin >/dev/null 2>&1; then
            echo "ok"
        else
            echo "unreachable"
        fi
    else
        echo "no_remote"
    fi
}

check_config() {
    if [ -f "$CONF_FILE" ]; then
        if grep -q 'FRAMEWORKS=' "$CONF_FILE"; then
            echo "ok"
        else
            echo "incomplete"
        fi
    else
        echo "missing"
    fi
}

check_sync_state() {
    if [ -f "$STATE_FILE" ]; then
        local status
        status=$(jq -r '.status' "$STATE_FILE" 2>/dev/null || echo "unknown")
        local last_sync
        last_sync=$(jq -r '.last_sync' "$STATE_FILE" 2>/dev/null || echo "never")
        echo "$status:$last_sync"
    else
        echo "never:never"
    fi
}

main() {
    local issues=0
    local results=()

    # 1. Symlinks
    local symlink_result
    symlink_result=$(check_symlinks)
    local broken="${symlink_result%%:*}"
    local fixed="${symlink_result##*:}"

    if [ "$broken" -gt 0 ]; then
        ((issues++)) || true
        results+=("symlink_broken:$broken:$fixed")
    else
        results+=("symlink_ok:0:0")
    fi

    # 2. Cron
    local cron_result
    cron_result=$(check_cron)
    [ "$cron_result" != "ok" ] && ((issues++)) || true
    results+=("cron:$cron_result")

    # 3. Git
    local git_result
    git_result=$(check_git)
    [ "$git_result" != "ok" ] && [ "$git_result" != "no_remote" ] && ((issues++)) || true
    results+=("git:$git_result")

    # 4. Config
    local config_result
    config_result=$(check_config)
    [ "$config_result" != "ok" ] && ((issues++)) || true
    results+=("config:$config_result")

    # 5. Sync state
    local sync_result
    sync_result=$(check_sync_state)
    results+=("sync:$sync_result")

    # Output
    if $JSON_OUTPUT; then
        local json="{"
        json+="\"symlinks\":{\"broken\":$broken,\"fixed\":$fixed},"
        json+="\"cron\":\"$cron_result\","
        json+="\"git\":\"$git_result\","
        json+="\"config\":\"$config_result\","
        json+="\"sync\":{\"status\":\"${sync_result%%:*}\",\"last\":\"${sync_result##*:}\"},"
        json+="\"issues\":$issues"
        json+="}"
        echo "$json"
    else
        echo "🏥 Skill-Hub 健康检查"
        echo ""

        # Symlinks
        if [ "$broken" -gt 0 ]; then
            echo "❌ Symlinks: $broken 个断裂"
            $FIX_MODE && echo "   已修复 $fixed 个"
            echo "   运行 skill-sync doctor --fix 自动修复"
        else
            echo "✅ Symlinks: 正常"
        fi

        # Cron
        case "$cron_result" in
            ok) echo "✅ 自动同步: 已启用" ;;
            missing) echo "⚠️  自动同步: 未配置 (运行 install.sh)" ;;
        esac

        # Git
        case "$git_result" in
            ok) echo "✅ Git 远程: 可达" ;;
            no_remote) echo "ℹ️  Git 远程: 未配置 (纯本地模式)" ;;
            unreachable) echo "❌ Git 远程: 不可达 (检查网络/认证)" ;;
            not_git_repo) echo "❌ Git: 不是仓库" ;;
        esac

        # Config
        case "$config_result" in
            ok) echo "✅ 配置: 完整" ;;
            incomplete) echo "⚠️  配置: 不完整 (缺少 FRAMEWORKS)" ;;
            missing) echo "❌ 配置: 不存在" ;;
        esac

        # Sync
        local sync_status="${sync_result%%:*}"
        local sync_last="${sync_result##*:}"
        case "$sync_status" in
            ok) echo "✅ 最近同步: $sync_last" ;;
            conflict) echo "❌ 同步冲突: 请运行 skill-sync sync 解决" ;;
            never) echo "ℹ️  尚未同步过" ;;
            *) echo "⚠️  同步状态: $sync_status" ;;
        esac

        echo ""
        if [ "$issues" -eq 0 ]; then
            echo "✅ 一切正常"
        else
            echo "发现 $issues 个问题"
            $FIX_MODE || echo "运行 skill-sync doctor --fix 尝试自动修复"
        fi
    fi

    [ "$issues" -gt 0 ] && exit 1
    exit 0
}

main
