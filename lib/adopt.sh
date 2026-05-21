#!/usr/bin/env bash
# adopt.sh — Move skill into hub with copy-verify-swap safety
# Usage: skill-sync adopt <name> [--fix] [--json]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
SKILLS_DIR="$HUB_DIR/skills"

JSON_OUTPUT=false
AUTO_FIX=false
SKILL_NAME=""

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        --fix) AUTO_FIX=true ;;
        --*) ;;
        *) SKILL_NAME="$arg" ;;
    esac
done

if [ -z "$SKILL_NAME" ]; then
    echo "Usage: skill-sync adopt <skill-name> [--fix] [--json]" >&2
    exit 1
fi

# Source config
[ -f "$CONF_FILE" ] && source "$CONF_FILE"
# Expand $HOME and ~ in FRAMEWORKS
FRAMEWORKS="${FRAMEWORKS//$HOME/$HOME}"
FRAMEWORKS="${FRAMEWORKS//~/$HOME}"
# Find the skill in any registered framework
find_skill_source() {
    local fw_str="${FRAMEWORKS:-}"
    local IFS=','
    for fw_entry in $fw_str; do
        local fw_name="${fw_entry%%:*}"
        local fw_path="${fw_entry#*:}"
        fw_path="${fw_path/#\~/$HOME}"

        local candidate="$fw_path/$SKILL_NAME"
        if [ -d "$candidate" ] && [ ! -L "$candidate" ]; then
            echo "$fw_name:$candidate"
            return 0
        fi
    done
    return 1
}

# Run portability check
run_check() {
    local target_dir="$1"
    local result
    result=$(bash "$HUB_DIR/lib/check.sh" "$target_dir" --adopt-check 2>&1) || true
    echo "$result"
}

# Fix portability issues
fix_issues() {
    local target_dir="$1"
    bash "$HUB_DIR/lib/check.sh" "$target_dir" --fix 2>&1 || true
}

main() {
    # Already in hub?
    if [ -d "$SKILLS_DIR/$SKILL_NAME" ]; then
        if $JSON_OUTPUT; then
            echo "{\"status\":\"already_managed\",\"skill\":\"$SKILL_NAME\"}"
        else
            echo "⚠️  $SKILL_NAME is already in skill-hub"
        fi
        exit 0
    fi

    # Find source
    local source_info
    if ! source_info=$(find_skill_source); then
        if $JSON_OUTPUT; then
            echo "{\"status\":\"not_found\",\"skill\":\"$SKILL_NAME\"}"
        else
            echo "❌ $SKILL_NAME not found in any framework (or already a symlink)" >&2
        fi
        exit 1
    fi

    local source_fw="${source_info%%:*}"
    local source_dir="${source_info#*:}"

    # Run portability check
    local check_result
    check_result=$(run_check "$source_dir")
    local has_block=false
    if echo "$check_result" | grep -q '"level":"block"'; then
        has_block=true
    fi
    if echo "$check_result" | grep -q '阻断'; then
        has_block=true
    fi

    if $has_block && ! $AUTO_FIX; then
        if $JSON_OUTPUT; then
            echo "{\"status\":\"blocked\",\"skill\":\"$SKILL_NAME\",\"issues\":$(echo "$check_result" | tail -1)}"
        else
            echo "❌ $SKILL_NAME has portability issues that must be fixed:"
            echo "$check_result"
            echo ""
            echo "Run with --fix to auto-fix, or fix manually and retry."
        fi
        exit 1
    fi

    # Auto-fix if requested
    if $has_block && $AUTO_FIX; then
        fix_issues "$source_dir"
    fi

    # STEP 1: Copy to hub (source stays intact)
    mkdir -p "$SKILLS_DIR"
    cp -a "$source_dir" "$SKILLS_DIR/$SKILL_NAME"

    # STEP 2: Verify copy
    if ! diff -r "$source_dir" "$SKILLS_DIR/$SKILL_NAME" >/dev/null 2>&1; then
        # Verification failed — clean up copy, abort
        rm -rf "$SKILLS_DIR/$SKILL_NAME"
        if $JSON_OUTPUT; then
            echo "{\"status\":\"verify_failed\",\"skill\":\"$SKILL_NAME\"}"
        else
            echo "❌ Copy verification failed. Original directory untouched." >&2
        fi
        exit 1
    fi

    # STEP 3: Remove source, create symlinks to all frameworks
    rm -rf "$source_dir"

    local fw_str="${FRAMEWORKS:-}"
    local IFS=','
    local deployed=0
    for fw_entry in $fw_str; do
        local fw_name="${fw_entry%%:*}"
        local fw_path="${fw_entry#*:}"
        fw_path="${fw_path/#\~/$HOME}"

        [ -d "$fw_path" ] || mkdir -p "$fw_path"
        ln -sfn "$SKILLS_DIR/$SKILL_NAME" "$fw_path/$SKILL_NAME"
        ((deployed++)) || true
    done

    # Git commit
    cd "$HUB_DIR"
    git add "skills/$SKILL_NAME"
    git commit -m "adopt: $SKILL_NAME (from $source_fw)" --quiet 2>/dev/null || true

    if $JSON_OUTPUT; then
        echo "{\"status\":\"adopted\",\"skill\":\"$SKILL_NAME\",\"frameworks\":$deployed,\"source_framework\":\"$source_fw\"}"
    else
        echo "✅ $SKILL_NAME adopted into skill-hub"
        echo "   Source: $source_fw"
        echo "   Deployed to: $deployed framework(s)"
    fi
}

main
