#!/usr/bin/env bash
# sync.sh — Git sync: pull, commit, push with conflict handling
# Usage: skill-sync sync [--json]
#        skill-sync cron (called by cron, same logic)

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
STATE_FILE="$HUB_DIR/.sync-state.json"

JSON_OUTPUT=false
CRON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        --cron) CRON_MODE=true ;;
    esac
done

# Write sync state
write_state() {
    local status="$1"
    local message="${2:-}"
    local committed="${3:-[]}"
    local pulled="${4:-[]}"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$STATE_FILE" <<EOF
{
  "last_sync": "$ts",
  "status": "$status",
  "message": "$message",
  "committed": $committed,
  "pulled": $pulled
}
EOF
}

main() {
    cd "$HUB_DIR"

    # Check if git repo
    if [ ! -d ".git" ]; then
        write_state "error" "Not a git repository"
        if $JSON_OUTPUT; then
            echo '{"status":"error","message":"Not a git repository"}'
        else
            echo "❌ Not a git repository" >&2
        fi
        exit 1
    fi

    # Check if remote exists
    local has_remote=false
    if git remote get-url origin >/dev/null 2>&1; then
        has_remote=true
    fi

    local committed_files="[]"
    local pulled_files="[]"
    local had_conflict=false

    # STEP 1: Pull remote changes
    if $has_remote; then
        if ! git pull --rebase --autostash origin "$(git branch --show-current)" 2>/dev/null; then
            # Check for merge conflicts
            if git diff --name-only --diff-filter=U 2>/dev/null | head -1 | grep -q .; then
                had_conflict=true
                local conflicted
                conflicted=$(git diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                write_state "conflict" "Merge conflict in: $conflicted"

                if ! $CRON_MODE; then
                    if $JSON_OUTPUT; then
                        echo "{\"status\":\"conflict\",\"files\":\"$conflicted\"}"
                    else
                        echo "❌ 同步冲突: $conflicted"
                        echo "   请手动解决冲突后运行 skill-sync sync"
                    fi
                fi
                exit 1
            fi
            # Other pull failure (network, auth) — non-fatal for cron
            if ! $CRON_MODE; then
                echo "⚠️  git pull failed (network/auth issue?)" >&2
            fi
        else
            # Track pulled files
            local pulled
            pulled=$(git diff --name-only HEAD@{1} HEAD 2>/dev/null | head -20 || true)
            if [ -n "$pulled" ]; then
                pulled_files=$(echo "$pulled" | jq -R -s 'split("\n") | map(select(length > 0))')
            fi
        fi
    fi

    # STEP 2: Commit local changes
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
        local ts
        ts=$(date +"%Y%m%d-%H%M%S")
        local changed
        changed=$(git diff --cached --name-only | head -20 | jq -R -s 'split("\n") | map(select(length > 0))')
        git commit -m "auto-sync: $ts" --quiet 2>/dev/null
        committed_files="$changed"
    fi

    # STEP 3: Push
    if $has_remote; then
        if ! git push origin "$(git branch --show-current)" 2>/dev/null; then
            if ! $CRON_MODE; then
                echo "⚠️  git push failed (network/auth issue?)" >&2
            fi
        fi
    fi

    # STEP 4: Rebuild symlinks (in case new skills were pulled)
    bash "$HUB_DIR/lib/setup.sh" --json >/dev/null 2>&1 || true

    # Write success state
    write_state "ok" "" "$committed_files" "$pulled_files"

    # Output
    if $JSON_OUTPUT; then
        echo "{\"status\":\"ok\",\"committed\":$committed_files,\"pulled\":$pulled_files}"
    elif ! $CRON_MODE; then
        local committed_count
        committed_count=$(echo "$committed_files" | jq 'length' 2>/dev/null || echo "0")
        local pulled_count
        pulled_count=$(echo "$pulled_files" | jq 'length' 2>/dev/null || echo "0")

        if [ "$committed_count" = "0" ] && [ "$pulled_count" = "0" ]; then
            echo "✅ 已是最新状态"
        else
            [ "$committed_count" != "0" ] && echo "📤 推送 $committed_count 个文件变更"
            [ "$pulled_count" != "0" ] && echo "📥 拉取 $pulled_count 个文件更新"
            echo "✅ 同步完成"
        fi
    fi
}

main
