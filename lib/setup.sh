#!/usr/bin/env bash
# setup.sh — Create symlinks from skill-hub/skills/ to all registered frameworks
# Called by: skill-sync setup, install.sh, sync.sh (after pull)

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"
SKILLS_DIR="$HUB_DIR/skills"
JSON_OUTPUT=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
    esac
done

# Source config if exists
if [ -f "$CONF_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$CONF_FILE"
    set +a
fi

# Parse FRAMEWORKS from config
# Format: FRAMEWORKS=cc:~/.claude/skills,cursor:~/.cursor/skills
parse_frameworks() {
    local fw_str="${FRAMEWORKS:-}"
    if [ -z "$fw_str" ]; then
        echo "No frameworks configured. Run: skill-sync register" >&2
        return 1
    fi
    # Expand $HOME in the string
    fw_str="${fw_str//\$HOME/$HOME}"
    fw_str="${fw_str//\~/$HOME}"
    echo "$fw_str"
}

# Deploy a single skill to a single framework
deploy_skill() {
    local skill_name="$1"
    local fw_name="$2"
    local fw_dir="$3"
    local skill_src="$SKILLS_DIR/$skill_name"
    local skill_dest="$fw_dir/$skill_name"

    # Skip if skill doesn't exist in hub
    [ -d "$skill_src" ] || return 0

    # Skip if already a symlink pointing to the right place
    if [ -L "$skill_dest" ]; then
        local current_target
        current_target=$(readlink "$skill_dest")
        if [ "$current_target" = "$skill_src" ]; then
            return 0
        fi
        # Wrong symlink — remove it
        rm "$skill_dest"
    fi

    # If a real directory exists, back it up
    if [ -d "$skill_dest" ] && [ ! -L "$skill_dest" ]; then
        local backup="$skill_dest.pre-skillhub"
        if [ ! -d "$backup" ]; then
            mv "$skill_dest" "$backup"
            echo "  ⚠️  Backed up existing $skill_dest → $backup" >&2
        else
            rm -rf "$skill_dest"
        fi
    fi

    # Remove broken symlink
    [ -L "$skill_dest" ] && ! [ -d "$skill_dest" ] && rm "$skill_dest"

    # Determine if adapter is needed
    local skill_file
    skill_file=$(detect_skill_file "$fw_name")

    if [ "$skill_file" = "SKILL.md" ]; then
        # Native format — just symlink
        ln -sfn "$skill_src" "$skill_dest"
    else
        # Need adapter — generate framework-specific file
        local adapter="$HUB_DIR/adapters/${fw_name}.sh"
        if [ -f "$adapter" ]; then
            mkdir -p "$skill_dest"
            bash "$adapter" "$skill_src/SKILL.md" "$skill_dest/$skill_file"
            # Symlink scripts if they exist
            [ -d "$skill_src/scripts" ] && ln -sfn "$skill_src/scripts" "$skill_dest/scripts"
        else
            # No adapter — fallback to symlink (best effort)
            ln -sfn "$skill_src" "$skill_dest"
            echo "  ⚠️  No adapter for $fw_name, using symlink (may not work)" >&2
        fi
    fi
}

# Detect the skill filename for a framework
detect_skill_file() {
    local fw_name="$1"
    case "$fw_name" in
        cc|claude-code|cursor|cx) echo "SKILL.md" ;;
        hermes) echo "skill.yaml" ;;
        *) echo "SKILL.md" ;;  # Default to markdown
    esac
}

# Process FRAMEWORK conditional sections in SKILL.md
# Keeps only the section matching current framework, removes others
process_framework_sections() {
    local content="$1"
    local fw_name="$2"

    # If no FRAMEWORK markers, return as-is
    echo "$content" | grep -q 'FRAMEWORK:' || { echo "$content"; return; }

    local result=""
    local in_section=false
    local current_fw=""

    while IFS= read -r line; do
        if [[ "$line" =~ \<!--\ FRAMEWORK:([a-z-]+)\ --\> ]]; then
            in_section=true
            current_fw="${BASH_REMATCH[1]}"
            # Include if it matches our framework or is "generic"
            if [ "$current_fw" = "$fw_name" ] || [ "$current_fw" = "generic" ]; then
                : # include — don't add the marker line itself
            fi
            continue
        fi

        if [[ "$line" =~ \<!--\ /FRAMEWORK:([a-z-]+)\ --\> ]]; then
            in_section=false
            current_fw=""
            continue
        fi

        if $in_section; then
            if [ "$current_fw" = "$fw_name" ] || [ "$current_fw" = "generic" ]; then
                result+="$line"$'\n'
            fi
        else
            result+="$line"$'\n'
        fi
    done <<< "$content"

    echo "$result"
}

# Main
main() {
    local fw_str
    fw_str=$(parse_frameworks) || exit 1

    local deployed=0
    local skipped=0

    # Iterate over skills in hub
    if [ -d "$SKILLS_DIR" ]; then
        for skill_dir in "$SKILLS_DIR"/*/; do
            [ -d "$skill_dir" ] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")

            # Deploy to each framework
            local IFS=','
            for fw_entry in $fw_str; do
                local fw_name="${fw_entry%%:*}"
                local fw_path="${fw_entry#*:}"
                # Expand ~
                fw_path="${fw_path/#\~/$HOME}"

                [ -d "$fw_path" ] || mkdir -p "$fw_path"
                deploy_skill "$skill_name" "$fw_name" "$fw_path"
                ((deployed++)) || true
            done
        done
    fi

    if $JSON_OUTPUT; then
        echo "{\"deployed\": $deployed, \"skipped\": $skipped}"
    else
        echo "✅ Setup complete: $deployed link(s) created/verified"
    fi
}

main
