# Skill-Hub

**跨机器跨框架的 Skill 统一管理工具。一套 skill，所有机器、所有框架自动同步。**

## 一句话安装

告诉你的 AI 助手：

> 安装 skill-hub skill

或者手动：

```bash
# 1. Fork 本仓库到你的 GitHub，设为 Private
# 2. 克隆你的 fork
git clone git@github.com:<你的用户名>/skill-hub.git ~/skill-hub
cd ~/skill-hub && bash install.sh --non-interactive \
  --frameworks "cc:$HOME/.claude/skills" --interval 5
git remote add upstream git@github.com:aganhui/skill-hub.git
```

## 它能做什么

| 功能 | 说明 |
|------|------|
| 跨机器同步 | Git 驱动，push/pull 自动同步 |
| 跨框架共享 | symlink + 适配器，CC/CX/Hermes/任意框架 |
| 自动同步 | cron 每 N 分钟自动 commit + push + pull |
| 可移植性检查 | 检测绝对路径/硬编码密钥/本机IP，确保到处能跑 |
| 安全扫描 | 检测破坏性命令/远程代码执行风险 |
| 框架适配 | FRAMEWORK 条件段，一份 SKILL.md 适配所有框架 |

## 工作原理

```
skill-hub (git repo)  ──symlink──→  各框架 skills 目录
     ↑                                    │
     │ git push/pull                      │ 编辑 = 修改源文件
     │                                    │
  远程机器                              本机
```

- skill-hub 是唯一真相源（Single Source of Truth）
- 各框架目录里的 skill 是 symlink → 指向 skill-hub
- 编辑任何框架里的 skill = 编辑 skill-hub 里的源文件
- cron 自动 git commit + push + pull

## 部署

### 首次部署（新机器）

1. 在 GitHub 上 fork 本仓库，设为 **Private**
2. 在新机器上执行：

```bash
# 克隆你自己的 fork
git clone git@github.com:<你的用户名>/skill-hub.git ~/skill-hub

# 非交互安装（指定框架和同步间隔）
cd ~/skill-hub && bash install.sh --non-interactive \
  --frameworks "cc:$HOME/.claude/skills" \
  --interval 5

# 添加上游仓库，以便同步工具更新
git remote add upstream git@github.com:aganhui/skill-hub.git
```

或者告诉 Claude Code：

> 帮我部署 skill-hub，按顺序执行以下步骤：
> 1. 克隆私有仓库：git clone git@github.com:\<你的用户名\>/skill-hub.git ~/skill-hub
> 2. 非交互安装：cd ~/skill-hub && bash install.sh --non-interactive --frameworks "cc:$HOME/.claude/skills" --interval 5
> 3. 添加上游仓库：git remote add upstream git@github.com:aganhui/skill-hub.git
> 4. 运行 skill-sync doctor 验证安装状态
> 5. 运行 skill-sync status 确认 skill 列表

### 双仓库说明

| 仓库 | 用途 | 可见性 |
|------|------|--------|
| `upstream` → `aganhui/skill-hub` | 工具代码（bin/, lib/, docs/ 等） | 公开 |
| `origin` → `<你的用户名>/skill-hub` | 你的 skill 数据（skills/ 目录） | 私有 |

**核心规则：工具代码走 upstream，skill 数据走 origin。**

## 更新

### 同步工具更新（上游有新功能/修复）

```bash
cd ~/skill-hub
git fetch upstream
git merge upstream/main
git push origin main
```

### 同步 skill 数据（多台机器之间）

自动：cron 每 5 分钟执行 `skill-sync sync`（git pull + push）

手动：

```bash
~/skill-hub/bin/skill-sync sync
```

### 入库/出库 skill

```bash
# 入库
~/skill-hub/bin/skill-sync adopt my-skill

# 出库（还原为独立目录）
~/skill-hub/bin/skill-sync detach my-skill
```

## 快速开始

### 迁移已有 skill

```bash
# 查看哪些 skill 还没入库
~/skill-hub/bin/skill-sync status

# 入库（自动检查可移植性）
~/skill-hub/bin/skill-sync adopt tavily-search

# 有问题？加 --fix 自动修复
~/skill-hub/bin/skill-sync adopt tavily-search --fix
```

### 新建 skill

在 CC 中创建新 skill 时，Claude 会询问是否加入 skill-hub。

或者手动：
```bash
~/skill-hub/bin/skill-sync adopt my-new-skill
```

## 命令列表

```bash
skill-sync adopt <name>         # 将已有 skill 移入仓库
skill-sync detach <name>        # 脱离管理，还原为真实目录
skill-sync check <name>         # 可移植性审查
skill-sync check <name> --sec   # 安全扫描
skill-sync status               # 同步状态总览
skill-sync setup                # 重建所有框架的 symlinks
skill-sync sync                 # 手动触发一次同步
skill-sync doctor               # 健康检查
skill-sync register             # 注册新框架
skill-sync list                 # 列出已管理 skills
```

所有命令支持 `--json` 参数获取机器可读输出。

## 多框架适配

在 SKILL.md 中用 FRAMEWORK 条件段标记框架差异：

```markdown
<!-- FRAMEWORK:cc -->
使用 Skill 工具调用
<!-- /FRAMEWORK:cc -->

<!-- FRAMEWORK:hermes -->
使用 activate_skill 调用
<!-- /FRAMEWORK:hermes -->
```

部署时只保留当前框架的段落。

## Skill 规范

每个 skill 至少包含一个 SKILL.md，头部 frontmatter 声明元数据和依赖：

```yaml
---
name: my-skill
version: 1.0.0
description: What this skill does
depends:
  tools: [curl]
  env:
    MY_API_KEY:
      required: true
  os: [macos, linux]
  frameworks: [cc, cx, hermes]
tags: [search, api]
---
```

详见 [docs/spec.md](docs/spec.md)。

## 卸载

```bash
~/skill-hub/uninstall.sh
```

还原所有 symlink 为真实目录，移除 cron，清理 CLAUDE.md。可选是否删除仓库。

## 文档

- [完整命令参考](docs/commands.md)
- [Skill 规范](docs/spec.md)
- [适配器开发指南](docs/adapter-guide.md)
- [框架注册指南](docs/framework-guide.md)

## License

MIT
