# 框架注册指南

## 自动检测的框架

`install.sh` 自动检测以下框架：

| 框架 | 检测路径 | 格式 |
|------|----------|------|
| Claude Code (cc) | `~/.claude/skills` | Markdown (SKILL.md) |
| Cursor | `~/.cursor/skills` | Markdown (SKILL.md) |
| Hermes | `~/.hermes/skills` | YAML |
| OpenClaw | `~/.openclaw/skills` | Markdown |

## 手动注册

```bash
# 交互式
skill-sync register

# 非交互式
skill-sync register \
  --name my-agent \
  --path ~/.my-agent/skills \
  --skill-file prompt.md \
  --adapter my-agent \
  --non-interactive
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--name` | 框架名称（小写+连字符） | 必填 |
| `--path` | skills 目录绝对路径 | 必填 |
| `--skill-file` | 框架的 skill 主文件名 | SKILL.md |
| `--adapter` | 适配器名称（在 adapters/ 目录下） | 无（直接 symlink） |

## 配置文件

框架信息存储在 `~/skill-hub/.skill-sync.conf`：

```ini
FRAMEWORKS=cc:/home/user/.claude/skills,hermes:/home/user/.hermes/skills
REMOTE=git@github.com:user/skills.git
INTERVAL=5
ADAPTER_hermes=hermes
SKILL_FILE_hermes=skill.yaml
```

## 多机器配置

不同机器可以注册不同的框架组合：

```
# Mac 桌面
FRAMEWORKS=cc:/Users/xxx/.claude/skills,cursor:/Users/xxx/.cursor/skills

# Linux 服务器
FRAMEWORKS=cc:/home/xxx/.claude/skills,hermes:/home/xxx/.hermes/skills

# Docker 容器
FRAMEWORKS=cc:/root/.claude/skills
```

每台机器的 `.skill-sync.conf` 独立管理，共用同一个 git 仓库。
