# Git Submodule 操作指南

## 概述

本项目采用 Git Submodule 技术管理外部依赖库（如 godot-cpp），实现代码的模块化管理与复用。本指南详细说明子模块的初始化、更新、提交及日常运维流程。

## 子模块配置

### 当前子模块列表

| 子模块路径 | 远程仓库 | 锁定分支 | 用途 |
| --- | --- | --- | --- |
| `gdextension/godot-cpp` | https://github.com/godotengine/godot-cpp.git | 4.3 | Godot C++ 绑定库 |

### .gitmodules 配置说明

```ini
[submodule "gdextension/godot-cpp"]
	path = gdextension/godot-cpp
	url = https://github.com/godotengine/godot-cpp.git
	branch = 4.3
	update = checkout
	shallow = true
```

- **branch**: 锁定到稳定分支 4.3，确保版本一致性
- **update**: 采用 checkout 模式，子模块保持独立提交记录
- **shallow**: 启用浅克隆，减少克隆时间和空间占用

## 标准化操作流程

### 1. 首次克隆项目（含子模块）

```bash
# 方式一：克隆时自动初始化子模块
git clone --recurse-submodules 你的仓库地址

# 方式二：先克隆主项目，再初始化子模块
git clone 你的仓库地址
cd 项目目录
git submodule init
git submodule update
```

### 2. 初始化已有项目的子模块

```bash
# 初始化子模块配置
git submodule init

# 更新子模块到主项目记录的版本
git submodule update
```

### 3. 更新子模块

#### 3.1 更新到远程最新版本（保持分支锁定）

```bash
# 更新所有子模块
git submodule update --remote

# 更新指定子模块
git submodule update --remote gdextension/godot-cpp
```

#### 3.2 手动切换子模块版本

```bash
# 进入子模块目录
cd gdextension/godot-cpp

# 切换到指定分支或提交
git checkout 4.3
# 或
git checkout <commit-hash>

# 返回主项目目录
cd ../..

# 提交子模块版本变更
git add gdextension/godot-cpp
git commit -m "chore: update godot-cpp to version xxx"
```

### 4. 提交子模块变更

#### 4.1 子模块内部修改

```bash
# 进入子模块目录
cd gdextension/godot-cpp

# 查看子模块状态
git status

# 提交子模块内部修改（需有推送权限）
git add .
git commit -m "fix: xxx"
git push origin 4.3

# 返回主项目目录
cd ../..

# 更新主项目中子模块的引用
git add gdextension/godot-cpp
git commit -m "chore: update godot-cpp reference"
git push
```

#### 4.2 仅更新子模块引用

```bash
# 更新子模块到远程最新版本并提交引用
git submodule update --remote
git add gdextension/godot-cpp
git commit -m "chore: sync godot-cpp with upstream"
git push
```

### 5. 拉取包含子模块变更的更新

```bash
# 拉取主项目更新
git pull

# 更新子模块到新引用的版本
git submodule update
```

### 6. 递归拉取所有更新

```bash
# 拉取主项目和所有子模块的更新
git pull --recurse-submodules

# 如果子模块有新的提交，会自动更新
```

### 7. 删除子模块

```bash
# 1. 取消注册子模块
git submodule deinit -f gdextension/godot-cpp

# 2. 删除子模块目录
git rm -f gdextension/godot-cpp

# 3. 删除子模块缓存目录（可选）
rm -rf .git/modules/gdextension/godot-cpp
```

## 版本控制策略

### 子模块版本锁定原则

1. **主项目锁定特定提交**: 主项目 `.gitmodules` 记录子模块的特定 commit hash，确保所有开发者使用相同版本
2. **分支稳定性**: 子模块锁定到稳定分支（如 4.3），避免直接使用 master 分支
3. **定期同步**: 每周检查上游更新，确认兼容性后同步子模块版本

### 子模块更新审批流程

```
开发者提出更新需求
       ↓
检查上游 changelog
       ↓
本地测试兼容性
       ↓
提交 PR 并等待审核
       ↓
合并后通知团队同步
```

## 团队协作规范

### 新成员入职流程

1. 克隆项目时使用 `--recurse-submodules` 参数
2. 如果忘记使用，执行 `git submodule init && git submodule update`
3. 配置 Git 全局设置（可选）：
   ```bash
   git config --global submodule.recurse true
   ```

### 子模块变更通知机制

1. 子模块更新必须在 commit message 中明确说明
2. 更新后在团队群同步变更内容
3. 重要更新需附带兼容性说明

### 冲突处理

如果子模块引用发生冲突：

```bash
# 查看冲突状态
git status

# 手动解决冲突（编辑 .gitmodules 和 .git/config）
# 然后执行：
git add .gitmodules
git submodule update
```

## 环境验证

### 开发环境验证

```bash
# 验证子模块状态
git submodule status

# 预期输出示例：
#  d5cc777a89d899665fb61f1650ef0dc0cf6488c4 gdextension/godot-cpp (heads/4.3)

# 验证编译
cd gdextension/mouse_passthrough_extension
scons
```

### CI/CD 流程集成

```bash
# CI 环境初始化
git submodule init
git submodule update --remote

# 编译验证
python build.py

# 部署测试
```

## 常见问题

### 问题1：子模块显示未追踪的修改

```bash
# 原因：子模块目录有未提交的修改
cd gdextension/godot-cpp
git status

# 解决方案：提交或撤销修改
git stash  # 临时保存
# 或
git checkout .  # 撤销修改
```

### 问题2：子模块更新后编译失败

```bash
# 原因：新版本可能引入破坏性变更
git submodule update --remote
git log --oneline -3  # 查看最近提交

# 解决方案：回退到稳定版本
cd gdextension/godot-cpp
git checkout <稳定commit>
cd ../..
git add gdextension/godot-cpp
git commit -m "revert: godot-cpp to stable version"
```

### 问题3：克隆时子模块失败

```bash
# 原因：网络问题或权限不足
git submodule update --init --recursive

# 如果失败，手动克隆
cd gdextension
git clone https://github.com/godotengine/godot-cpp.git
cd godot-cpp
git checkout 4.3
cd ../..
git add gdextension/godot-cpp
```

## 最佳实践

1. **避免频繁更新**: 子模块更新会影响所有开发者，需谨慎操作
2. **版本兼容性测试**: 更新前必须在本地验证编译和功能
3. **文档同步**: 更新子模块版本时同步更新相关文档
4. **使用浅克隆**: 减少克隆时间，`.gitmodules` 已配置 `shallow = true`

## 命令速查表

| 命令 | 说明 |
| --- | --- |
| `git submodule init` | 初始化子模块配置 |
| `git submodule update` | 更新子模块到主项目记录的版本 |
| `git submodule update --remote` | 更新子模块到远程最新版本 |
| `git submodule status` | 查看子模块状态 |
| `git clone --recurse-submodules` | 克隆项目时同步子模块 |
| `git pull --recurse-submodules` | 拉取时同步子模块 |
| `git submodule deinit <path>` | 取消注册子模块 |
| `git rm <submodule-path>` | 删除子模块 |

## 总结

通过 Git Submodule 技术，本项目实现了：

- ✅ 模块化依赖管理
- ✅ 版本锁定与一致性保障
- ✅ 团队协作效率提升
- ✅ CI/CD 无缝集成

团队成员应严格遵循本指南的操作流程，确保子模块管理的规范性和可靠性。
