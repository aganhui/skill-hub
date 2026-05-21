#!/usr/bin/env bash
# status.sh — Show sync status and managed skills
# Usage: skill-sync status [--json]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
STATE_FILE="$HUB_DIR/.sync-state.json"
SKILLS_DIR="$HUB_DIR/skills"

JSON_OUTPUT=false

for arg in "$@"; do
    [ "$arg" = "--json" ] && JSON_OUTPUT=true
done

if [ -f "$CONF_FILE" ]; then
    set -a
    source "$CONF_FILE"
    set +a
    FRAMEWORKS="${FRAMEWORKS//\$HOME/$HOME}"
    FRAMEWORKS="${FRAMEWORKS//\~/$HOME}"
fi

main() {
    # Count managed skills
    local managed=()
    if [ -d "$SKILLS_DIR" ]; then
        for d in "$SKILLS_DIR"/*/; do
            [ -d "$d" ] || continue
            managed+=("$(basename "$d")")
        done
    fi

    # Find unmanaged skills
    local unmanaged=()
    local fw_str="${FRAMEWORKS:-}"
    local seen=()

    if [ -n "$fw_str" ]; then
        local IFS=','
        for fw_entry in $fw_str; do
            local fw_path="${fw_entry#*:}"
            fw_path="${fw_path/#\~/$HOME}"
            [ -d "$fw_path" ] || continue

            for d in "$fw_path"/*/; do
                [ -d "$d" ] || continue
                local name
                name=$(basename "$d")

                # Skip if already seen
                local already_seen=false
                for s in "${seen[@]+"${seen[@]}"}"; do
                    [ "$s" = "$name" ] && already_seen=true && break
                done
                $already_seen && continue
                seen+=("$name")

                # Skip if managed (symlink to hub)
                if [ -L "${d%/}" ]; then
                    local target
                    target=$(readlink "${d%/}")
                    [[ "$target" == "$HUB_DIR/"* ]] && continue
                fi

                # Skip if name matches a managed skill
                local is_managed=false
                for m in "${managed[@]+"${managed[@]}"}"; do
                    [ "$m" = "$name" ] && is_managed=true && break
                done
                $is_managed && continue

                unmanaged+=("$name")
            done
        done
    fi

    # Sync state
    local sync_status="never"
    local last_sync="never"
    if [ -f "$STATE_FILE" ]; then
        sync_status=$(jq -r '.status' "$STATE_FILE" 2>/dev/null || echo "unknown")
        last_sync=$(jq -r '.last_sync' "$STATE_FILE" 2>/dev/null || echo "never")
    fi

    # Output
    if $JSON_OUTPUT; then
        local managed_json
        managed_json=$(printf '%s\n' "${managed[@]+"${managed[@]}"}" | jq -R -s 'split("\n") | map(select(length > 0))')
        local unmanaged_json
        unmanaged_json=$(printf '%s\n' "${unmanaged[@]+"${unmanaged[@]}"}" | jq -R -s 'split("\n") | map(select(length > 0))')
        echo "{\"managed\":$managed_json,\"unmanaged\":$unmanaged_json,\"sync\":{\"status\":\"$sync_status\",\"last\":\"$last_sync\"},\"frameworks\":\"$FRAMEWORKS\"}"
    else
        echo "📊 Skill-Hub 状态"
        echo ""

        echo "  已管理: ${#managed[@]} 个"
        for m in "${managed[@]+"${managed[@]}"}"; do
            echo "    - $m"
        done

        if [ ${#unmanaged[@]} -gt 0 ]; then
            echo ""
            echo "  未管理: ${#unmanaged[@]} 个"
            for u in "${unmanaged[@]+"${unmanaged[@]}"}"; do
                echo "    - $u (运行 skill-sync adopt $u 入库)"
            done
        fi

        echo ""
        echo "  同步: $sync_status"
        echo "  最近: $last_sync"
        echo "  框架: $FRAMEWORKS"
    fi
}

main
