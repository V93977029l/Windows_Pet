# Git 工作流程指南

## 分支策略

本项目采用**分支开发-主干发布**的工作流（类似GitHub Flow但简化版），以适应小团队的协作需求。

### 分支分类

1. **`main`** - 主分支（保护分支）
   - 始终保持可部署、可运行的稳定状态
   - 所有最终发布的代码都在这里
   - **直接在main分支上开发是禁止的**

2. **个人开发分支** - 开发者专属分支
   - 命名规范：`dev/<名字>`，例如 `dev/zhangsan`、`dev/lisi`
   - 每个开发者在自己的分支上进行日常开发
   - 可以随意提交、实验、回退

## 标准工作流程

### 0. 首次设置（新入职/首次克隆项目）

```bash
# 方式一：克隆时自动初始化子模块（推荐）
git clone --recurse-submodules 你的仓库地址

# 方式二：先克隆主项目，再初始化子模块
git clone 你的仓库地址
cd 项目目录
git submodule init
git submodule update
```

### 1. 开始新工作前

```bash
# 切换到main分支
git checkout main

# 拉取最新的main分支代码（包含子模块更新）
git pull --recurse-submodules origin main

# 切换回自己的开发分支
git checkout dev/你的名字

# 从main合并最新代码到你的分支
git merge main

# 同步子模块状态
git submodule update
```

### 2. 日常开发

在自己的开发分支上正常工作：

```bash
# 查看当前状态
git status

# 添加修改的文件
git add .

# 提交（使用有意义的提交信息）
git commit -m "feat: 添加拖拽功能"

# 推送到远程自己的分支
git push origin dev/你的名字
```

### 3. 准备合并到main分支

当你的功能开发完成并经过测试后：

```bash
# 确保在自己的分支上
git checkout dev/你的名字

# 再次拉取最新的main，避免冲突
git fetch origin
git merge origin/main

# 同步子模块
git submodule update

# 解决可能出现的冲突（如果有）
# 编辑冲突文件后：
git add .
git commit -m "merge: 解决与main的冲突"

# 推送到远程
git push origin dev/你的名字
```

### 4. 合并到main

#### 方式一：通过Pull/Merge Request（推荐）

1. 在Git仓库平台（GitHub/GitLab/Gitee）上创建Pull/Merge Request
2. 从你的分支 `dev/你的名字` 合并到 `main`
3. 等待代码审查（如果需要）
4. 合并PR

#### 方式二：直接合并（适用于信任度高的小团队）

```bash
# 切换到main分支
git checkout main

# 拉取最新代码（确保别人没有在你测试期间提交）
git pull --recurse-submodules origin main

# 合并你的开发分支
git merge dev/你的名字

# 推送到远程main
git push origin main
```

### 5. 合并后该做什么？（重点！）

**这是你现在需要做的步骤：**

```bash
# 1. 切换回你的开发分支
git checkout dev/你的名字

# 2. 从main拉取最新的合并结果（包括你刚才的提交和可能别人的提交）
git pull --recurse-submodules origin main

# 3. 现在你的分支已经和main同步，可以开始下一个功能的开发了！
```

## 子模块工作流程

本项目使用Git Submodule管理外部依赖，详细操作请参考 [GitSubmodule操作指南.md](tool-guides/GitSubmodule操作指南.md)

### 常用子模块命令速查：

```bash
# 查看子模块状态
git submodule status

# 更新子模块到主项目记录的版本
git submodule update

# 更新所有子模块到远程最新版本（谨慎使用！）
git submodule update --remote

# 拉取主项目和所有子模块的更新
git pull --recurse-submodules

# 进入子模块目录操作
cd external/godot-cpp
git status  # 查看子模块状态
cd ../..
```

## 提交信息规范

使用规范的提交信息，便于生成CHANGELOG和理解历史：

```
<type>: <subject>

<可选的详细描述>
```

**Type类型：**
- `feat` - 新功能
- `fix` - 修复bug
- `refactor` - 重构代码（不改变功能）
- `style` - 代码格式调整
- `docs` - 文档更新
- `test` - 测试相关
- `chore` - 构建/工具链相关
- `submodule` - 子模块更新

**示例：**
```
feat: 添加系统托盘图标功能
fix: 修复窗口拖拽时的闪烁问题
docs: 更新Git工作流程文档
submodule: 更新godot-cpp到最新版本
```

## 冲突解决指南

### 1. 识别冲突

当Git无法自动合并时，会显示类似信息：

```
Auto-merging file.txt
CONFLICT (content): Merge conflict in file.txt
Automatic merge failed; fix conflicts and then commit the result.
```

### 2. 查看冲突文件

打开冲突文件，会看到类似标记：

```
<<<<<<< HEAD
这是你的代码
=======
这是别人的代码
>>>>>>> branch-name
```

### 3. 解决冲突步骤

```bash
# 1. 查看所有冲突文件
git status

# 2. 手动编辑冲突文件，删除标记，保留需要的代码

# 3. 标记冲突已解决
git add <冲突文件>

# 4. 完成合并提交
git commit -m "merge: 解决与main的冲突"

# 5. 推送到远程
git push origin dev/你的名字
```

### 4. 子模块冲突

如果子模块有冲突：

```bash
# 查看子模块状态
git submodule status

# 如果子模块有未提交的修改，先处理子模块的修改
cd external/godot-cpp
git status
# 提交或撤销子模块的修改
cd ../..

# 然后继续主项目的合并
```

## 常用Git命令速查表

### 基础操作

| 命令 | 说明 |
|------|------|
| `git status` | 查看当前状态 |
| `git add .` | 添加所有修改 |
| `git add <file>` | 添加指定文件 |
| `git commit -m "<message>"` | 提交修改 |
| `git push origin <branch>` | 推送到远程 |
| `git pull origin <branch>` | 拉取远程更新 |
| `git checkout <branch>` | 切换分支 |
| `git merge <branch>` | 合并分支 |
| `git log --oneline` | 查看简洁提交历史 |
| `git log --graph` | 查看图形化提交历史 |

### 分支操作

| 命令 | 说明 |
|------|------|
| `git branch` | 查看本地分支 |
| `git branch -a` | 查看所有分支（含远程） |
| `git branch <name>` | 创建新分支 |
| `git branch -d <name>` | 删除本地分支 |
| `git checkout -b <name>` | 创建并切换到新分支 |

### 撤销操作

| 命令 | 说明 |
|------|------|
| `git restore <file>` | 撤销工作区修改 |
| `git restore --staged <file>` | 取消暂存 |
| `git reset HEAD~1` | 撤销最近一次提交（保留修改） |
| `git reset --hard HEAD~1` | 撤销最近一次提交（丢弃修改） |
| `git stash` | 临时保存修改 |
| `git stash pop` | 恢复临时保存的修改 |

### 子模块操作

| 命令 | 说明 |
|------|------|
| `git submodule status` | 查看子模块状态 |
| `git submodule init` | 初始化子模块 |
| `git submodule update` | 更新子模块到指定版本 |
| `git submodule update --remote` | 更新子模块到远程最新 |
| `git pull --recurse-submodules` | 拉取主项目和子模块 |

## 常见问题

### Q: 我刚把代码合并到main了，接下来怎么办？
**A:** 按照上面"合并后该做什么"的步骤，切换回你的开发分支，从main拉取最新代码，然后开始下一个功能的开发。

### Q: 别人在main上提交了代码，我怎么同步？
**A:** 在你的开发分支上执行 `git pull --recurse-submodules origin main` 即可。

### Q: 遇到冲突怎么办？
**A:** 
1. Git会标记冲突文件
2. 打开文件，搜索 `<<<<<<<`、`=======`、`>>>>>>>` 标记
3. 手动编辑保留需要的代码
4. 执行 `git add .` 和 `git commit` 完成解决

### Q: 我可以在自己的分支上强制推送吗？
**A:** 可以，你的分支你做主。但不要强制推送到main分支。

### Q: 子模块显示有修改怎么办？
**A:** 
1. 进入子模块目录查看状态：`cd external/godot-cpp && git status`
2. 如果是意外修改，撤销：`git checkout .`
3. 如果是需要的修改，在子模块内提交，然后在主项目 `git add` 子模块目录

### Q: 如何查看谁修改了某行代码？
**A:** 使用 `git blame <file>` 查看每行代码的最后修改者。

### Q: 如何临时保存当前工作去切换分支？
**A:** 使用 `git stash` 保存，切换分支，回来后用 `git stash pop` 恢复。

## 工作流检查清单

### 合并到main前检查
- [ ] 代码已经过本地测试通过
- [ ] 从main拉取了最新代码
- [ ] 解决了所有冲突
- [ ] 子模块状态正确
- [ ] 提交信息规范

### 合并后检查
- [ ] 切换回自己的开发分支
- [ ] 从main同步了最新代码
- [ ] 子模块已更新
- [ ] 可以开始新功能开发

## 图示

```
main:    ──●──────────●─────────●───
              \        /         /
dev/张三:     ●──●───●         /
                      \       /
dev/李四:              ●──●──●
```

每个开发者在自己的分支上开发，完成后合并回main，然后同步最新的main到自己的分支。
