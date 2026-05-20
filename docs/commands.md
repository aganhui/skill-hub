# skill-sync 命令参考

## adopt

```bash
skill-sync adopt <name> [--fix] [--json]
```

将已有 skill 移入 skill-hub 仓库并创建 symlinks。

**流程**:
1. 在所有已注册框架中查找该 skill
2. 运行可移植性检查 (`check`)
3. 如果有阻断级问题，拒绝入库（除非 `--fix`）
4. 复制到 `~/skill-hub/skills/<name>/`
5. 验证副本与原件一致
6. 删除原件，创建 symlink
7. 在所有已注册框架中创建 symlink
8. Git commit

**--fix**: 自动修复可移植性问题（绝对路径→`$HOME`，硬编码密钥→环境变量）

**--json**: 机器可读输出

## detach

```bash
skill-sync detach <name> [--keep-hub] [--json]
```

将 skill 从 skill-hub 管理中移出，还原为真实目录。

**--keep-hub**: 保留 skill-hub 中的副本（作为模板），默认删除

## check

```bash
skill-sync check <name> [--security] [--fix] [--json]
```

可移植性审查。三个级别：

| 级别 | 含义 | adopt 时 |
|------|------|----------|
| block | 必须修复 | 阻止入库 |
| warn | 建议修复 | 允许入库 |
| info | 可选优化 | 允许入库 |

**--security**: 增加安全扫描（破坏性命令、远程代码执行、敏感文件访问等）

**--fix**: 自动修复可修复的问题

**检测项**:
- 绝对路径（`/Users/xxx/`）
- 本机服务（`localhost:8999`）
- 私有网络 IP（`192.168.x.x`）
- 硬编码密钥（`tvly-xxx`、`sk-xxx` 等）
- 框架专属工具调用
- OS 专属命令
- 可选依赖未声明
- 环境变量无默认值

## status

```bash
skill-sync status [--json]
```

显示已管理/未管理的 skill 列表和同步状态。

## setup

```bash
skill-sync setup [--json]
```

重建所有框架的 symlinks。幂等操作，可安全重复运行。

- 对于 markdown 格式框架（CC/CX/Cursor）：直接 symlink
- 对于需要适配的框架：运行适配器生成框架格式文件
- 处理 FRAMEWORK 条件段裁剪
- 已存在的正确 symlink 会被跳过
- 非 symlink 的现有目录会被备份为 `.pre-skillhub`

## sync

```bash
skill-sync sync [--json]
```

手动触发一次完整同步：`git pull → git add/commit → git push → setup`

同步状态写入 `~/skill-hub/.sync-state.json`。

## doctor

```bash
skill-sync doctor [--json] [--fix]
```

健康检查：
- Symlinks 是否有效（断裂检测）
- Cron 是否在运行
- Git remote 是否可达
- 配置是否完整
- 最近同步状态

**--fix**: 自动删除断裂的 symlink

## register

```bash
skill-sync register --name <name> --path <path> [--skill-file <file>] [--adapter <adapter>] [--non-interactive] [--json]
```

注册新的 agent 框架。注册后自动部署已有 skill 到新框架。

## list

```bash
skill-sync list [--json]
```

列出所有已管理的 skill 及版本。

## cron

```bash
skill-sync cron
```

由 cron/launchd 调用，执行 sync 的静默版本。不输出到 stdout（除非有冲突）。
