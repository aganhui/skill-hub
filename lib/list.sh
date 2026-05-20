#!/usr/bin/env bash
# list.sh — List all managed skills
# Usage: skill-sync list [--json]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$HUB_DIR/skills"

JSON_OUTPUT=false

for arg in "$@"; do
    [ "$arg" = "--json" ] && JSON_OUTPUT=true
done

main() {
    local skills=()

    if [ -d "$SKILLS_DIR" ]; then
        for d in "$SKILLS_DIR"/*/; do
            [ -d "$d" ] || continue
            local name
            name=$(basename "$d")

            # Try to read version from frontmatter
            local version=""
            if [ -f "$d/SKILL.md" ]; then
                version=$(grep -m1 '^version:' "$d/SKILL.md" 2>/dev/null | sed 's/version:\s*//' || true)
            fi

            skills+=("$name${version:+:$version}")
        done
    fi

    if $JSON_OUTPUT; then
        local json="["
        local first=true
        for entry in "${skills[@]}"; do
            local name="${entry%%:*}"
            local version="${entry#*:}"
            [ "$version" = "$name" ] && version=""
            $first || json+=","
            first=false
            json+="{\"name\":\"$name\"${version:+,\"version\":\"$version\"}}"
        done
        json+="]"
        echo "$json"
    else
        if [ ${#skills[@]} -eq 0 ]; then
            echo "没有已管理的 skill"
        else
            for entry in "${skills[@]}"; do
                local name="${entry%%:*}"
                local version="${entry#*:}"
                [ "$version" = "$name" ] && version=""
                echo "  - $name${version:+ (v$version)}"
            done
        fi
    fi
}

main
