---
name: skill-hub
version: 1.0.0
description: Cross-machine, cross-framework skill sync and management
depends:
  tools: [git]
  os: [macos, linux]
  frameworks: [cc, cx, hermes, any]
tags: [sync, manage, cross-machine, cross-framework]
---

# Skill-Hub

跨机器跨框架的 Skill 统一管理工具。一套 skill，所有机器、所有框架自动同步。

## 安装

用户要求安装 skill-hub 时：

1. 克隆仓库:
```bash
git clone https://github.com/user/skill-hub.git ~/skill-hub
```

2. 向用户确认配置（自动检测的项不用问）:
   - 要管理的框架（自动检测已安装的框架，列出供确认）
   - Git 远程仓库（用于跨机器同步，留空则纯本地）
   - 同步间隔（默认5分钟）

3. 执行安装:
```bash
~/skill-hub/install.sh --non-interactive \
  --frameworks "cc:$HOME/.claude/skills" \
  --remote "<用户提供的URL>" \
  --interval 5
```

4. 确认安装结果:
```bash
~/skill-hub/bin/skill-sync status
```

## 每次对话开始

静默执行 `~/skill-hub/bin/skill-sync sync`。仅在有冲突或新 skill 时才报告给用户。

## 新建 skill 时

创建新 skill 到框架 skills 目录后，必须询问用户：
"这个 skill 是否加入 skill-hub 统一管理？"

用户同意 → 执行:
```bash
~/skill-hub/bin/skill-sync adopt <skill-name>
```

如有可移植性问题，向用户报告并建议修复方案。

## 用户意图映射

| 用户说 | 操作 |
|--------|------|
| 入库/adopt xxx | `~/skill-hub/bin/skill-sync adopt xxx` |
| 移出/detach xxx | `~/skill-hub/bin/skill-sync detach xxx` |
| 检查/check xxx | `~/skill-hub/bin/skill-sync check xxx` |
| 安全检查 xxx | `~/skill-hub/bin/skill-sync check xxx --security` |
| 状态/status | `~/skill-hub/bin/skill-sync status` |
| 同步/sync | `~/skill-hub/bin/skill-sync sync` |
| 加框架/register | `~/skill-hub/bin/skill-sync register` |
| 健康检查/doctor | `~/skill-hub/bin/skill-sync doctor` |
| 列出/list | `~/skill-hub/bin/skill-sync list` |
| 卸载 | `~/skill-hub/uninstall.sh` |

## 遇到问题时

1. skill 不可用 → `~/skill-hub/bin/skill-sync doctor`
2. 同步冲突 → 读取 `~/skill-hub/.sync-state.json`，引导用户解决
3. adopt 报错 → 加 `--fix` 重试：`~/skill-hub/bin/skill-sync adopt xxx --fix`
4. 命令详情 → 读取 `~/skill-hub/docs/commands.md`
5. 适配器开发 → 读取 `~/skill-hub/docs/adapter-guide.md`

## 所有命令使用 `--json` 参数获取机器可读输出

例: `~/skill-hub/bin/skill-sync status --json`
