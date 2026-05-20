# Skill 规范

## 目录结构

每个 skill 是 `~/skill-hub/skills/<name>/` 目录，至少包含一个 `SKILL.md`。

```
skills/<name>/
├── SKILL.md          # 必需：skill 主文件
├── scripts/          # 可选：辅助脚本
│   ├── run.sh
│   └── utils.py
└── templates/        # 可选：模板文件
```

## SKILL.md 格式

### Frontmatter（必需）

```yaml
---
name: my-skill
version: 1.0.0
description: 一句话描述
depends:
  tools: [curl, jq]           # 需要的外部工具
  env:                         # 需要的环境变量
    MY_API_KEY:
      required: true
      description: "API key for ..."
    MY_BASE_URL:
      required: false
      default: "https://api.example.com"
  os: [macos, linux]          # 支持的操作系统
  frameworks: [cc, cx, hermes] # 支持的框架
tags: [search, api, web]
---
```

### 正文

Markdown 格式，包含 agent 执行该 skill 所需的全部指令。

### 多框架适配：FRAMEWORK 条件段

用注释标记框架差异部分：

```markdown
<!-- FRAMEWORK:cc -->
使用 Skill 工具调用: `Skill(skill="my-skill")`
<!-- /FRAMEWORK:cc -->

<!-- FRAMEWORK:hermes -->
使用 activate_skill: `activate_skill(name="my-skill")`
<!-- /FRAMEWORK:hermes -->

<!-- FRAMEWORK:generic -->
直接读取本文件内容作为指令注入
<!-- /FRAMEWORK:generic -->
```

`skill-sync setup` 部署时只保留当前框架的段落。

**规则**:
- `FRAMEWORK:generic` 段落作为所有框架的回退
- 条件段外的内容对所有框架可见
- 每个 `<!-- FRAMEWORK:xxx -->` 必须有对应的 `<!-- /FRAMEWORK:xxx -->`
- 框架名小写，用连字符分隔（如 `claude-code`）

### 可移植性要求

入库 skill 必须通过 `skill-sync check`：

| 禁止 | 替代方案 |
|------|----------|
| 绝对路径 `/Users/xxx/` | `$HOME/xxx/` 或相对路径 |
| 本机地址 `localhost:8999` | `${HOST:-localhost}:${PORT:-8999}` |
| 硬编码密钥 `sk-xxx` | `$API_KEY` + `depends.env` 声明 |
| 私有网络 IP `192.168.x.x` | 环境变量 + 配置文件 |

## 版本号

遵循语义化版本 (semver)：`MAJOR.MINOR.PATCH`

- MAJOR: 不兼容的变更
- MINOR: 向后兼容的功能新增
- PATCH: 向后兼容的问题修复

## 环境变量管理

skill 需要的环境变量统一声明在 frontmatter 的 `depends.env` 中。

用户在本机配置环境变量的推荐方式：

```bash
# 在 shell profile 中
export MY_API_KEY=xxx

# 或在 skill-hub 环境配置中
echo "MY_API_KEY=xxx" >> ~/skill-hub/.env
```
