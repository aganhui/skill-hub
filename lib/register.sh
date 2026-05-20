#!/usr/bin/env bash
# register.sh — Register a new framework
# Usage: skill-sync register [--name <name>] [--path <path>] [--skill-file <file>] [--adapter <adapter>] [--non-interactive] [--json]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$HUB_DIR/.skill-sync.conf"

JSON_OUTPUT=false
NON_INTERACTIVE=false
FW_NAME=""
FW_PATH=""
FW_SKILL_FILE=""
FW_ADAPTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --name) FW_NAME="$2"; shift 2 ;;
        --path) FW_PATH="$2"; shift 2 ;;
        --skill-file) FW_SKILL_FILE="$2"; shift 2 ;;
        --adapter) FW_ADAPTER="$2"; shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        *) shift ;;
    esac
done

main() {
    # Interactive prompts if not provided
    if ! $NON_INTERACTIVE; then
        [ -z "$FW_NAME" ] && read -p "框架名称: " FW_NAME
        [ -z "$FW_PATH" ] && read -p "skills 目录路径: " FW_PATH
        [ -z "$FW_SKILL_FILE" ] && read -p "skill 文件名 [SKILL.md]: " FW_SKILL_FILE
        FW_SKILL_FILE="${FW_SKILL_FILE:-SKILL.md}"
        [ -z "$FW_ADAPTER" ] && read -p "适配器 (留空=直接symlink): " FW_ADAPTER
    fi

    if [ -z "$FW_NAME" ] || [ -z "$FW_PATH" ]; then
        echo "❌ 框架名称和路径不能为空" >&2
        exit 1
    fi

    # Expand ~
    FW_PATH="${FW_PATH/#\~/$HOME}"

    # Ensure directory exists
    mkdir -p "$FW_PATH"

    # Read current config
    local current_frameworks=""
    if [ -f "$CONF_FILE" ]; then
        current_frameworks=$(grep '^FRAMEWORKS=' "$CONF_FILE" | cut -d= -f2-)
    fi

    # Add new framework
    local new_entry="$FW_NAME:$FW_PATH"
    if [ -n "$current_frameworks" ]; then
        # Check if already registered
        if echo "$current_frameworks" | grep -q "$FW_NAME:"; then
            if $JSON_OUTPUT; then
                echo "{\"status\":\"already_registered\",\"framework\":\"$FW_NAME\"}"
            else
                echo "⚠️  $FW_NAME 已经注册过了"
            fi
            exit 0
        fi
        current_frameworks="$current_frameworks,$new_entry"
    else
        current_frameworks="$new_entry"
    fi

    # Write config
    if [ -f "$CONF_FILE" ] && grep -q '^FRAMEWORKS=' "$CONF_FILE"; then
        sed -i.bak "s|^FRAMEWORKS=.*|FRAMEWORKS=$current_frameworks|" "$CONF_FILE"
        rm -f "$CONF_FILE.bak"
    else
        echo "FRAMEWORKS=$current_frameworks" >> "$CONF_FILE"
    fi

    # Write adapter config if specified
    if [ -n "$FW_ADAPTER" ]; then
        echo "ADAPTER_${FW_NAME}=$FW_ADAPTER" >> "$CONF_FILE"
        echo "SKILL_FILE_${FW_NAME}=$FW_SKILL_FILE" >> "$CONF_FILE"
    fi

    # Deploy existing skills to new framework
    source "$CONF_FILE"
    bash "$HUB_DIR/lib/setup.sh" >/dev/null 2>&1 || true

    if $JSON_OUTPUT; then
        echo "{\"status\":\"registered\",\"framework\":\"$FW_NAME\",\"path\":\"$FW_PATH\",\"adapter\":\"${FW_ADAPTER:-none}\"}"
    else
        echo "✅ $FW_NAME 已注册 ($FW_PATH)"
        echo "   已有 skill 已部署到新框架"
    fi
}

main
