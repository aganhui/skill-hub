# Skill-Hub

**跨机器跨框架的 Skill 统一管理工具。一套 skill，所有机器、所有框架自动同步。**

## 一句话安装

告诉你的 AI 助手：

> 安装 skill-hub skill

或者手动安装：

```bash
git clone https://github.com/user/skill-hub.git ~/skill-hub
cd ~/skill-hub && ./install.sh
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

## 快速开始

### 1. 安装

```bash
git clone https://github.com/user/skill-hub.git ~/skill-hub
cd ~/skill-hub && ./install.sh
```

安装过程会：
- 自动检测已安装的框架（CC、Cursor、Hermes 等）
- 引导你选择要管理的框架
- 配置 git 远程仓库（可选，纯本地也行）
- 设置自动同步 cron
- 在 CLAUDE.md 中注入 skill-hub 规则

### 2. 迁移已有 skill

```bash
# 查看哪些 skill 还没入库
~/skill-hub/bin/skill-sync status

# 入库（自动检查可移植性）
~/skill-hub/bin/skill-sync adopt tavily-search

# 有问题？加 --fix 自动修复
~/skill-hub/bin/skill-sync adopt tavily-search --fix
```

### 3. 新建 skill

在 CC 中创建新 skill 时，Claude 会询问是否加入 skill-hub。

或者手动：
```bash
~/skill-hub/bin/skill-sync adopt my-new-skill
```

### 4. 第二台机器

```bash
git clone <your-skill-repo> ~/skill-hub
cd ~/skill-hub && ./install.sh
```

自动拉取所有已有 skill 并部署到本机框架。

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
