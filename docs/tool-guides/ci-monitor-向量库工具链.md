# CI Monitor + 向量错误库 — 使用指南

> 记录项目的 **MCP 工具系统**和**结构化错误知识库**。
> 这两者是 AI 辅助开发的核心 — 让 AI 能够**程序化查询 CI 状态**和**语义化查历史错误**。

---

## 一、系统总览

```
┌───────────────────────────────────────────────────────────────────┐
│  MCP 工具层 (tools/ci_monitor/server.py)                           │
│  ──────────────────────────────────────────────────────────────   │
│                                                                     │
│  • check_ci_status(branch, limit)     — 查询最新 CI 状态          │
│  • wait_for_ci(branch, max_wait)      — 阻塞等待 CI 完成           │
│  • get_ci_failure_details(run_id)     — 获取失败 job 详情          │
│  • query_similar_errors(query, limit) — 语义搜索历史错误           │
│  • store_ci_error(symptom, fix, ...)  — 写入新错误到向量库         │
│                                                                     │
│  ↓ ↓ ↓                                                           │
│                                                                     │
│  GitHub Actions API ←───────────→ 向量错误库 (tools/vector_db)    │
│                                  ┌──────────────────────────────┐  │
│                                  │ errors.json — 结构化数据     │  │
│                                  │ ChromaDB — 向量索引          │  │
│                                  └──────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

**角色分工：**

| 组件                         | 职责                               | 人读还是 AI 读          |
| ---------------------------- | ---------------------------------- | ----------------------- |
| `tools/ci_monitor/server.py` | MCP 工具服务器，暴露工具给 AI      | **AI 为主**，人类看文档 |
| `tools/vector_db/`           | 向量错误库，结构化记录所有历史错误 | **AI 为主**             |
| `docs/CI操作指南.md`         | CI 流水线配置、手动操作说明        | **人类为主**            |
| `docs/working_log.md`        | 从向量库自动生成的人类快速参考     | **人类为主**            |

---

## 二、CI Monitor MCP 工具详解

### 2.1 配置文件

`tools/ci_monitor/mcp_config.json`

```json
{
  "mcpServers": {
    "ci-monitor": {
      "command": "python",
      "args": ["tools/ci_monitor/server.py"],
      "cwd": "f:/VSCode/game"
    }
  }
}
```

> 将此文件注册到你的 AI 客户端（Cursor、Claude Desktop 等）的 MCP 设置中。**注册后 AI 就能自动调用这些工具查询 CI 状态。**

### 2.2 工具清单

#### `check_ci_status` — 查询 CI 状态

```
参数:
  branch   string   默认 "main"   — 查询哪个分支的 CI
  limit    integer  默认 3        — 显示最近几次运行

返回:
  最近 N 次 CI 运行的状态（成功/失败/进行中）
```

**典型使用场景：**

- 刚提交到 `dev/fan`，问 AI："CI 跑起来了吗？" → AI 调此工具查询
- main 分支 PR 合并前，确认 CI 是绿色

#### `wait_for_ci` — 阻塞等待 CI 完成

```
参数:
  branch       string   默认 "main"
  poll_interval integer  默认 30 秒 — 轮询间隔
  max_wait     integer  默认 1200 秒 (20分钟)

返回:
  CI 完成后的结果。失败时自动附加向量库中相似错误的修复建议。
```

**典型使用场景：**

- 提交改动后等待 CI 完成然后合 PR
- 失败时 AI 自动查历史相似错误，不会再让你盲调试

#### `get_ci_failure_details` — 获取失败详情

```
参数:
  run_id   string   必填 — CI 运行 ID

返回:
  所有失败 job 的名称和上下文信息
```

**典型使用场景：**

- 某个 CI 跑挂了，需要深入分析
- 将 run_id 传给 AI，它用此工具拉取失败详情

#### `query_similar_errors` — 语义搜索历史错误

```
参数:
  query    string   必填 — 错误描述 / 症状
  limit    integer  默认 3 — 返回多少个相似错误

返回:
  按相似度排序的历史错误列表，每个包含：症状 / 根因 / 修复方案
```

**典型使用场景：**

- 看到一个报错，不确定是不是之前踩过的坑
- 开发前先查询"有没有人遇到过类似问题"

#### `store_ci_error` — 写入新错误记录

```
参数:
  symptom    string  必填 — 发生了什么（人类可读的故障描述）
  root_cause string  必填 — 为什么发生（底层原因分析）
  fix        string  必填 — 怎么修（具体修复方案）
  error_type string  默认 "ci" — compilation/runtime/logic/ci/test/configuration
  module     string  默认 "github-actions" — 相关模块
  tags       string  默认 "" — 逗号分隔的关键词
  source     string  默认 "manual" — manual/ci/agent

返回:
  确认已存储
```

**典型使用场景：**

- 花了两小时才发现的 Bug，赶紧记下来避免下次再踩
- CI 挂了，查明原因后存一份，供 AI 未来查询

---

## 三、向量错误库（tools/vector_db）

### 3.1 核心理念

之前 `docs/working_log.md` 是**自由文本**，AI 难用、人类维护也累。现在改为**结构化数据**：

```
每条错误 = {
  "symptom":    "症状描述",
  "root_cause": "根本原因",
  "fix":        "修复方案",
  "error_type": "compilation | runtime | logic | ci | test | configuration",
  "module":     "相关模块",
  "tags":       ["关键词1", "关键词2"],
  "source":     "manual | ci | agent"
}
```

### 3.2 命令行操作

```bash
cd f:\VSCode\game

# 查看所有记录
python tools/vector_db/manage.py list

# 按类型筛选
python tools/vector_db/manage.py list --type ci

# 语义搜索（自然语言提问）
python tools/vector_db/manage.py query "导出 DLL 报错"

# 存储新错误
python tools/vector_db/manage.py store \
  --symptom "CI 报 Unable to resolve action actions/cache@v7" \
  --root-cause "actions/cache 没有发布 v7 版本，最高是 v5" \
  --fix "改成 actions/cache@v5，同时核对其他 action 的 node24 版本" \
  --type ci --module github-actions --tags "action,版本,node24"

# 查看统计
python tools/vector_db/manage.py stats
```

### 3.3 当前记录概览

| 类型     | 典型例子                                                    |
| -------- | ----------------------------------------------------------- |
| CI       | APPDATA cache, PowerShell `&&`, GDExtension target mismatch |
| 编译错误 | 删除 `.godot` 目录、class_name 位置                         |
| 逻辑错误 | 信号连接泄漏、变量遮蔽                                      |
| 其他     | pre-commit mixed-line-ending                                |

**查看完整列表：** `python tools/vector_db/manage.py list`

---

## 四、CI 失败后的标准操作流程

> 这是最重要的一节。当 CI 变红色时，按以下顺序操作：

### 步骤 1：查询 CI 状态（让 AI 做）

```
AI → 调用 check_ci_status(branch="dev/fan")
↓
确认哪个 job 失败了（test / build-export）
```

### 步骤 2：获取失败详情

```
AI → 调用 get_ci_failure_details(run_id="xxxxxx")
↓
读错误日志，定位：
• 是 action 版本号问题？
• 是 GDScript 语法错误？
• 是 GDExtension DLL 问题？
• 是测试用例失败？
```

### 步骤 3：查历史相似错误

```
AI → 调用 query_similar_errors(query="报错信息的关键词描述")
↓
检查是否有人遇到过同样问题
如果找到匹配记录，按记录的 fix 操作
```

### 步骤 4：本地修复 + 验证

- 代码层面修改
- 本地跑 `godot --headless` 验证编译通过
- 本地跑单元测试

### 步骤 5：如果是新错误 — 存下来

```
python tools/vector_db/manage.py store \
  --symptom "具体症状" \
  --root-cause "根本原因" \
  --fix "怎么修复" \
  --type ci --module github-actions --tags "关键词"
```

### 步骤 6：推送并等待 CI 变绿

```
AI → wait_for_ci(branch="dev/fan")
↓
确认变绿 → 提交 PR
```

---

## 五、代码扫描失败处理

`code_scanner.gd` 是 CI 的第一道门槛，在单元测试之前运行。常见问题处理：

| 错误类型       | 处理方式                                                                    |
| -------------- | --------------------------------------------------------------------------- |
| `print()` 残留 | 删除或改成 `push_warning()`/`push_error()`（GDScript 中用于调试的日志 API） |
| 空 TODO        | 补充具体说明文字，如 `# TODO: 实现宠物寻路 AI`                              |
| 超长行         | 拆成多行，或用中间变量存储                                                  |
| 语法错误       | 在 Godot 编辑器中打开该文件，Godot 会高亮显示错误行                         |

---

## 六、维护策略

### 6.1 什么时候应该存新错误

**满足任一条就该存：**

- 🚨 排查时间超过 30 分钟
- 🐛 是"重复犯过的错"（如果之前有记录就不会再花时间）
- 🔧 需要修改 CI 配置或 Godot 引擎相关设置
- 📚 有明确的症状/根因/修复三段式描述

**不需要存：**

- 打字错误（如拼写错误的路径，修了就好）
- 一次性文档修正
- 真正的"偶发"问题（如果后续重现再存）

### 6.2 错误描述怎么写才有用

**bad ❌：**

```
symptom: "CI 挂了"
root_cause: "有问题"
fix: "修复了"
```

**good ✅：**

```
symptom: "CI 报 Unable to resolve action 'actions/setup-python@v8', unable to find version v8"
root_cause: "actions/setup-python 实际发布的最高版本是 v6，没有 v8。之前写的版本号是错的。"
fix: "改成 actions/setup-python@v6。同时核对所有 action 的 node24 原生版本号：checkout@v6, cache@v5, upload-artifact@v6, setup-python@v6, action-gh-release@v3"
```

### 6.3 working_log.md 还需要维护吗？

**不需要手动维护。** 正确流程：

1. **直接在向量库存错误**：`python tools/vector_db/manage.py store ...`
2. **从向量库生成 working_log.md**（偶尔刷新一次）
3. 或者 **直接用 `manage.py list` / `manage.py query` 查询**

> 原则：**向量库是唯一真相来源**。working_log.md 只是给人类快速浏览的视图。

---

## 七、相关文件速查

| 文件                                    | 作用                                     |
| --------------------------------------- | ---------------------------------------- |
| `tools/ci_monitor/server.py`            | MCP 工具服务器，Python 实现              |
| `tools/ci_monitor/mcp_config.json`      | MCP 客户端注册配置                       |
| `tools/vector_db/errors.json`           | 结构化错误数据（**唯一真相来源**）       |
| `tools/vector_db/manage.py`             | 命令行管理入口（list/query/store/stats） |
| `tools/vector_db/query.py`              | 向量搜索实现                             |
| `tools/vector_db/store.py`              | 错误写入实现                             |
| `tools/vector_db/rebuild.py`            | 从 errors.json 重建向量索引              |
| `transparent-pet/tools/code_scanner.gd` | CI 代码扫描器脚本                        |
| `.github/workflows/ci.yml`              | CI 流水线配置                            |
| `docs/CI操作指南.md`                    | CI 操作指南（人类视角）                  |
| `docs/working_log.md`                   | 快速参考卡片（从向量库派生）             |

---

**维护者提示**：修改任何 action 版本号前，**先去官方仓库确认该 tag 确实存在**，特别是当 GitHub 提示 "Node.js is deprecated" 想升级时。升级后本地跑一遍 `python tools/vector_db/manage.py stats` 确认索引正常。
