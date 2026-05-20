# 适配器开发指南

适配器将 SKILL.md 转换为目标框架的原生格式。

## 何时需要适配器

- 框架使用 Markdown 格式 → **不需要**（直接 symlink）
- 框架使用 YAML/JSON 等不同格式 → **需要适配器**

## 适配器接口

适配器是一个可执行脚本（bash/python/等），接收两个参数：

```
<adapter.sh> <source_skill_md> <target_directory>
```

- `$1`: SKILL.md 的绝对路径
- `$2`: 目标框架 skill 目录的绝对路径

适配器必须在 `$2` 下生成框架所需的文件。

## 内置适配器

### yaml-framework.sh

将 SKILL.md 包装为 YAML 格式：

```bash
#!/usr/bin/env bash
SOURCE="$1"
TARGET="$2"

# 读取 frontmatter
META=$(sed -n '/^---$/,/^---$/p' "$SOURCE" | sed '1d;$d')

# 读取正文
BODY=$(sed '1,/^---$/d' "$SOURCE" | sed '1,/^---$/d')

# 生成 YAML
cat > "$TARGET/skill.yaml" <<EOF
$META
content: |
$(echo "$BODY" | sed 's/^/  /')
EOF
```

## 创建自定义适配器

1. 创建脚本: `~/skill-hub/adapters/<framework-name>.sh`
2. 注册框架时指定: `skill-sync register --name myfw --path ~/.myfw/skills --adapter myfw`

### 示例：Python 适配器

```python
#!/usr/bin/env python3
"""Adapter for Example Framework"""
import sys
import yaml
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])

# Parse SKILL.md
content = source.read_text()
parts = content.split('---', 2)
frontmatter = yaml.safe_load(parts[1]) if len(parts) > 1 else {}
body = parts[2].strip() if len(parts) > 2 else content

# Generate framework format
output = {
    'name': frontmatter.get('name', source.parent.name),
    'version': frontmatter.get('version', '1.0.0'),
    'instructions': body,
}

(target / 'config.json').write_text(
    json.dumps(output, indent=2, ensure_ascii=False)
)
```

## 测试适配器

```bash
# 手动测试
~/skill-hub/adapters/myfw.sh ~/skill-hub/skills/hello-world/SKILL.md /tmp/test-output

# 通过 skill-sync 测试
skill-sync register --name myfw --path /tmp/myfw --adapter myfw
skill-sync setup
ls /tmp/myfw/hello-world/
```
