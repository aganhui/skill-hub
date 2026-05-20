#!/usr/bin/env bash
# check.sh — Portability check for skills
# Usage: skill-sync check <name|path> [--json] [--fix] [--adopt-check] [--security]

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$HUB_DIR/skills"
RULES_FILE="$HUB_DIR/rules/portability.yaml"
SECURITY_RULES="$HUB_DIR/rules/security.yaml"

JSON_OUTPUT=false
AUTO_FIX=false
SECURITY_MODE=false
ADOPT_CHECK=false
TARGET=""

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        --fix) AUTO_FIX=true ;;
        --security) SECURITY_MODE=true ;;
        --adopt-check) ADOPT_CHECK=true ;;
        --*) ;;
        *) TARGET="$arg" ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "Usage: skill-sync check <skill-name|path> [--json] [--fix] [--security]" >&2
    exit 1
fi

# Resolve target path
resolve_target() {
    # If it's a skill name, find it
    if [ -d "$SKILLS_DIR/$TARGET" ]; then
        echo "$SKILLS_DIR/$TARGET"
        return
    fi
    # If it's already a path
    if [ -d "$TARGET" ]; then
        echo "$TARGET"
        return
    fi
    # Check in common framework dirs
    for dir in ~/.claude/skills ~/.cursor/skills ~/.hermes/skills; do
        if [ -d "$dir/$TARGET" ]; then
            echo "$dir/$TARGET"
            return
        fi
    done
    echo ""
}

# Check for absolute paths
check_absolute_paths() {
    local file="$1"
    grep -nE '/Users/[a-z_]+/|/home/[a-z_]+/' "$file" 2>/dev/null | \
        grep -v '\$HOME' | \
        grep -v '~/' | \
        while IFS=: read -r line_num content; do
            echo "block|$line_num|绝对路径|$(echo "$content" | grep -oE '/Users/[a-z_]+/[^\s"]+|/home/[a-z_]+/[^\s"]+' | head -1)|使用 \$HOME 替代"
        done
}

# Check for localhost/127.0.0.1
check_local_services() {
    local file="$1"
    grep -nE '(localhost|127\.0\.0\.1|0\.0\.0\.0)(:[0-9]+)?' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            echo "block|$line_num|本机服务|$(echo "$content" | grep -oE '(localhost|127\.0\.0\.1|0\.0\.0\.0)(:[0-9]+)?' | head -1)|移到环境变量"
        done
}

# Check for private network IPs
check_private_networks() {
    local file="$1"
    grep -nE '(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+)' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            echo "block|$line_num|私有网络|$(echo "$content" | grep -oE '(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+)' | head -1)|移到环境变量或配置"
        done
}

# Check for hardcoded secrets
check_hardcoded_secrets() {
    local file="$1"
    grep -nE '(tvly-|fc-|sk-|AVNS_|sb_publishable_|ghp_|gho_|AKIA|AIza)[a-zA-Z0-9_-]+' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            local secret
            secret=$(echo "$content" | grep -oE '(tvly-|fc-|sk-|AVNS_|sb_publishable_|ghp_|gho_|AKIA|AIza)[a-zA-Z0-9_-]+' | head -1)
            echo "block|$line_num|硬编码密钥|${secret:0:10}...|移到环境变量并在 depends.env 声明"
        done
}

# Check for framework-specific tools (warn level)
check_framework_specific() {
    local file="$1"
    grep -nE '(Skill\(|mcp__[a-z_]+__|TodoWrite|TaskCreate|activate_skill)' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            local tool
            tool=$(echo "$content" | grep -oE '(Skill\(|mcp__[a-z_]+__|TodoWrite|TaskCreate|activate_skill)' | head -1)
            echo "warn|$line_num|框架专属工具|$tool|使用 FRAMEWORK 条件段适配"
        done
}

# Check for OS-specific commands (warn level)
check_os_specific() {
    local file="$1"
    grep -nE '(networksetup|brew install|apt-get install|yum install)' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            local cmd
            cmd=$(echo "$content" | grep -oE '(networksetup|brew install|apt-get install|yum install)' | head -1)
            echo "warn|$line_num|OS专属命令|$cmd|提供跨平台替代"
        done
}

# Check for optional dependencies (info level)
check_optional_deps() {
    local file="$1"
    grep -nE '(fswatch|mitmproxy|pm2|docker|conda)\s' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            local dep
            dep=$(echo "$content" | grep -oE '(fswatch|mitmproxy|pm2|docker|conda)' | head -1)
            echo "info|$line_num|可选依赖|$dep|在 depends.tools 中声明"
        done
}

# Check for env vars without defaults (info level)
check_env_vars() {
    local file="$1"
    grep -nE '\$\{?[A-Z_]{3,}\}?' "$file" 2>/dev/null | \
        grep -vE '\$\{?(HOME|PATH|USER|SHELL|PWD|LANG)\}?' | \
        grep -vE ':-' | \
        while IFS=: read -r line_num content; do
            local var
            var=$(echo "$content" | grep -oE '\$[A-Z_]{3,}' | head -1)
            echo "info|$line_num|环境变量无默认值|$var|提供默认值: \${VAR:-default}"
        done
}

# Security checks
check_security() {
    local file="$1"
    # Destructive commands
    grep -nE 'rm\s+-rf\s+/|rm\s+-rf\s+~|rm\s+-rf\s+\$HOME' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            echo "critical|$line_num|破坏性命令|rm -rf|极度危险，建议移除"
        done
    # Remote code execution
    grep -nE 'curl\s+.*\|\s*(ba)?sh|wget\s+.*\|\s*(ba)?sh' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            echo "critical|$line_num|远程代码执行|curl|sh|极度危险，建议移除"
        done
    # Sensitive file access
    grep -nE '/etc/shadow|/etc/passwd|\.ssh/id_rsa|\.ssh/authorized_keys' "$file" 2>/dev/null | \
        while IFS=: read -r line_num content; do
            echo "critical|$line_num|敏感文件访问|ssh/key文件|极度危险，建议移除"
        done
}

# Auto-fix issues
auto_fix() {
    local target_dir="$1"
    find "$target_dir" -type f -name '*.md' -o -name '*.sh' | while read -r file; do
        # Fix absolute paths
        sed -i.bak "s|/Users/[a-z_]\+/|\\\$HOME/|g" "$file" 2>/dev/null || true
        sed -i.bak "s|/home/[a-z_]\+/|\\\$HOME/|g" "$file" 2>/dev/null || true
        # Fix hardcoded secrets — replace with env var reference
        # (This is a best-effort fix, manual review recommended)
        rm -f "${file}.bak"
    done
}

# Main
main() {
    local target_dir
    target_dir=$(resolve_target)

    if [ -z "$target_dir" ]; then
        if $JSON_OUTPUT; then
            echo "{\"status\":\"not_found\",\"skill\":\"$TARGET\"}"
        else
            echo "❌ Skill not found: $TARGET" >&2
        fi
        exit 1
    fi

    local issues=()
    local block_count=0
    local warn_count=0
    local info_count=0
    local critical_count=0

    # Scan all relevant files
    local files_to_check=()
    while IFS= read -r -d '' f; do
        files_to_check+=("$f")
    done < <(find "$target_dir" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)

    for file in "${files_to_check[@]}"; do
        local rel_file="${file#$target_dir/}"

        # Portability checks
        while IFS= read -r issue; do
            [ -z "$issue" ] && continue
            local level="${issue%%|*}"
            local rest="${issue#*|}"
            local line_num="${rest%%|*}"
            rest="${rest#*|}"
            local type="${rest%%|*}"
            rest="${rest#*|}"
            local value="${rest%%|*}"
            local fix="${rest#*|}"

            case "$level" in
                block) ((block_count++)) || true ;;
                warn) ((warn_count++)) || true ;;
                info) ((info_count++)) || true ;;
                critical) ((critical_count++)) || true ;;
            esac

            issues+=("$level|$rel_file:$line_num|$type|$value|$fix")
        done < <({
            check_absolute_paths "$file"
            check_local_services "$file"
            check_private_networks "$file"
            check_hardcoded_secrets "$file"
            check_framework_specific "$file"
            check_os_specific "$file"
            check_optional_deps "$file"
            check_env_vars "$file"
            $SECURITY_MODE && check_security "$file"
        })
    done

    # Auto-fix if requested
    if $AUTO_FIX && [ ${#issues[@]} -gt 0 ]; then
        auto_fix "$target_dir"
        # Re-check after fix
        exec bash "$0" "$TARGET" ${JSON_OUTPUT:+--json} ${SECURITY_MODE:+--security}
    fi

    # Output
    if $JSON_OUTPUT; then
        local json_issues="["
        local first=true
        for issue in "${issues[@]}"; do
            local level="${issue%%|*}"; local rest="${issue#*|}"
            local location="${rest%%|*}"; rest="${rest#*|}"
            local type="${rest%%|*}"; rest="${rest#*|}"
            local value="${rest%%|*}"; local fix="${rest#*|}"
            $first || json_issues+=","
            first=false
            json_issues+="{\"level\":\"$level\",\"location\":\"$location\",\"type\":\"$type\",\"value\":\"$value\",\"fix\":\"$fix\"}"
        done
        json_issues+="]"
        local passed="true"
        [ $block_count -gt 0 ] && passed="false"
        echo "{\"skill\":\"$TARGET\",\"passed\":$passed,\"block\":$block_count,\"warn\":$warn_count,\"info\":$info_count,\"critical\":$critical_count,\"issues\":$json_issues}"
    else
        echo "🔍 审查 $TARGET 可移植性"
        echo ""

        if $SECURITY_MODE && [ $critical_count -gt 0 ]; then
            echo "🚨 危险 (必须移除):"
            for issue in "${issues[@]}"; do
                local level="${issue%%|*}"
                [ "$level" != "critical" ] && continue
                local rest="${issue#*|}"
                echo "  $rest" | awk -F'|' '{printf "  %-30s %-15s %s\n  → %s\n", $1, $2, $3, $4}'
            done
            echo ""
        fi

        if [ $block_count -gt 0 ]; then
            echo "❌ 阻断 (必须修复):"
            for issue in "${issues[@]}"; do
                local level="${issue%%|*}"
                [ "$level" != "block" ] && continue
                local rest="${issue#*|}"
                echo "  $rest" | awk -F'|' '{printf "  %-30s %-12s %s\n  → %s\n", $1, $2, $3, $4}'
            done
            echo ""
        fi

        if [ $warn_count -gt 0 ]; then
            echo "⚠️  警告 (建议修复):"
            for issue in "${issues[@]}"; do
                local level="${issue%%|*}"
                [ "$level" != "warn" ] && continue
                local rest="${issue#*|}"
                echo "  $rest" | awk -F'|' '{printf "  %-30s %-12s %s\n  → %s\n", $1, $2, $3, $4}'
            done
            echo ""
        fi

        if [ $info_count -gt 0 ]; then
            echo "💡 提示 (可选优化):"
            for issue in "${issues[@]}"; do
                local level="${issue%%|*}"
                [ "$level" != "info" ] && continue
                local rest="${issue#*|}"
                echo "  $rest" | awk -F'|' '{printf "  %-30s %-12s %s\n  → %s\n", $1, $2, $3, $4}'
            done
            echo ""
        fi

        if [ $block_count -eq 0 ] && [ $warn_count -eq 0 ] && [ $info_count -eq 0 ] && [ $critical_count -eq 0 ]; then
            echo "✅ 未发现可移植性问题"
        else
            echo "结果: $block_count 阻断, $warn_count 警告, $info_count 提示"
            [ $critical_count -gt 0 ] && echo "🚨 $critical_count 安全危险"
        fi
    fi

    # Exit code: 1 if blocked or critical
    [ $block_count -gt 0 ] || [ $critical_count -gt 0 ] && exit 1
    exit 0
}

main
