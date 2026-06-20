# 开发日志 & 已知坑位 — 快速参考

> **⚠️ 本文件是从向量库派生的视图，不是真相来源**
>
> **唯一真相来源：** `tools/vector_db/errors.json`
> **操作工具：** `python tools/vector_db/manage.py`
>
> 存新错误 → 直接用命令行工具写向量库
> 查老错误 → 直接 `manage.py query "关键词"` 语义搜索
>
> 本文件只用于人类快速浏览，内容更新后可能滞后于向量库

---

## 一、查询方式

```bash
cd f:\VSCode\game

# 看所有记录
python tools/vector_db/manage.py list

# 看某一类
python tools/vector_db/manage.py list --type ci
python tools/vector_db/manage.py list --type logic

# 自然语言搜索（最常用）
python tools/vector_db/manage.py query "CI 报 action 不存在"
python tools/vector_db/manage.py query "导出 DLL"

# 统计
python tools/vector_db/manage.py stats
```

## 二、当前记录（从向量库同步，可能滞后）

### CI 相关

**1. GDExtension target mismatch（最近高发）**

- 症状：CI 构建导出失败 "Export failed: file not found at TransparentPet.exe"，Godot 输出为空
- 根因：GDExtension 编译目标是 `template_debug`，但导出步骤用的是 release。DLL 文件名不一致导致找不到
- 修复：将编译目标改为 `--target=template_release`。DLL 预编译后直接提交到仓库，CI 不做 SCons 编译，只做存在性校验

**2. APPDATA 在 cache 中不可用**

- 症状：GitHub Actions 中 `actions/cache` 的 `${{ env.APPDATA }}` 解析不到，导出模板缓存路径错误
- 根因：GitHub Actions 表达式中的 `env.` 取的是 workflow `env:` 块定义的变量，不是 Windows 系统环境变量
- 修复：在 PowerShell 步骤里用 `echo "VAR=$env:APPDATA\path" >> $env:GITHUB_ENV` 先写入环境变量，再引用 `${{ env.VAR }}`

**3. PowerShell 不支持 `&&`**

- 症状：CI 脚本中用 `cmd1 && cmd2` 报 "`&&` 不是此版本中的有效语句分隔符"
- 修复：用 `;` 分隔命令，或分两个独立的步骤调用

---

### Godot 引擎 / GDScript 相关

**4. class_name 必须在 extends 之前**

- 症状：Godot 4.x 报解析错误，类找不到
- 正确：`class_name MyClass` → `extends Node`
- 错误：`extends Node` → `class_name MyClass`

**5. 不要随便删除 `.godot/` 目录**

- 症状：删除后项目无法编译，UID 解析失败、GdUnit4 类找不到
- 根因：`.godot/` 是 Godot 的导入缓存
- 修复：用 Godot 编辑器重新打开项目，让其自动重建

**6. 复制场景文件 UID 冲突**

- 症状：复制 `.tscn` 后出现 class_name 重复声明、场景加载报错
- 根因：场景文件 UID 不变，Godot 认为是同一资源
- 修复：通过 Godot 编辑器复制（会分配新 UID），或手动修改 `.tscn` 文件中的 uid 字段

**7. 变量遮蔽基类属性**

- 症状：`var scale: float` 在 `extends Node2D` 的类中与 `Node2D.scale` 冲突
- 修复：重命名变量，如 `var pet_scale: float`

**8. 信号连接泄漏**

- 症状：宠物切换场景后信号回调仍被触发，导致已销毁节点的回调执行报错
- 修复：在 `_exit_tree()` 中调用 `disconnect()` 断开所有手动连接的信号

---

### 其他

**9. pre-commit mixed-line-ending**

- 症状：pre-commit hook 报 mixed-line-ending 失败
- 修复：pre-commit 自动修复后，`git add` 重新暂存，再次 commit

---

## 三、CI 流水线的关键配置

详见 `docs/CI操作指南.md`。关键要点：

- **触发分支**：`main` + `dev/*`
- **job 结构**：`test`（所有分支跑）→ `build-export`（仅 main 自动跑，dev/\* 可手动触发）
- **代码扫描**：CI 中在 test job 内运行 `transparent-pet/tools/code_scanner.gd`
- **action 版本**：严格按 `docs/CI操作指南.md` §7.5 表格，严禁写不存在的 tag
- **GDExtension**：DLL 预编译后提交，CI 只做存在性校验

## 四、CI 失败时的标准操作

1. `python tools/vector_db/manage.py query "错误信息关键词"` — 先查有没有历史记录
2. 如果有 → 按历史修复方案操作
3. 如果没有 → 先定位问题，修复后 `python tools/vector_db/manage.py store` 存一份
4. CI 变绿后再提交 PR / 合 main

> 完整流程见 `docs/tool-guides/ci-monitor-向量库工具链.md` §四
