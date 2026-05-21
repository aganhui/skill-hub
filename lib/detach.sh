#!/usr/bin/env bash
# detach.sh — Remove skill from hub management, restore as real directory
# Usage: skill-sync detach <name> [--keep-hub] [--json]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
SKILLS_DIR="$HUB_DIR/skills"

JSON_OUTPUT=false
KEEP_HUB=false
SKILL_NAME=""

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        --keep-hub) KEEP_HUB=true ;;
        --*) ;;
        *) SKILL_NAME="$arg" ;;
    esac
done

if [ -z "$SKILL_NAME" ]; then
    echo "Usage: skill-sync detach <skill-name> [--keep-hub] [--json]" >&2
    exit 1
fi

[ -f "$CONF_FILE" ] && source "$CONF_FILE"
# Expand $HOME and ~ in FRAMEWORKS
FRAMEWORKS="${FRAMEWORKS//$HOME/$HOME}"
FRAMEWORKS="${FRAMEWORKS//~/$HOME}"
main() {
    local hub_skill="$SKILLS_DIR/$SKILL_NAME"

    if [ ! -d "$hub_skill" ]; then
        if $JSON_OUTPUT; then
            echo "{\"status\":\"not_managed\",\"skill\":\"$SKILL_NAME\"}"
        else
            echo "⚠️  $SKILL_NAME is not in skill-hub"
        fi
        exit 0
    fi

    # Replace symlinks with real copies in each framework
    local fw_str="${FRAMEWORKS:-}"
    local IFS=','
    local restored=0

    for fw_entry in $fw_str; do
        local fw_name="${fw_entry%%:*}"
        local fw_path="${fw_entry#*:}"
        fw_path="${fw_path/#\~/$HOME}"

        local link="$fw_path/$SKILL_NAME"
        if [ -L "$link" ]; then
            local target
            target=$(readlink "$link")
            if [[ "$target" == "$HUB_DIR/"* ]]; then
                rm "$link"
                cp -a "$hub_skill" "$link"
                ((restored++)) || true
            fi
        fi
    done

    # Remove from hub (unless --keep-hub)
    if ! $KEEP_HUB; then
        rm -rf "$hub_skill"
        cd "$HUB_DIR"
        git add -A
        git commit -m "detach: $SKILL_NAME" --quiet 2>/dev/null || true
    fi

    if $JSON_OUTPUT; then
        echo "{\"status\":\"detached\",\"skill\":\"$SKILL_NAME\",\"restored_to\":$restored,\"kept_in_hub\":$KEEP_HUB}"
    else
        echo "✅ $SKILL_NAME detached from skill-hub"
        echo "   Restored as real directory in $restored framework(s)"
        $KEEP_HUB && echo "   Copy kept in skill-hub" || echo "   Removed from skill-hub"
    fi
}

main
