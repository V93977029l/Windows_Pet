---
alwaysApply: true
---
## CI/CD 与自动化测试工作流

> 面向 AI-Coding 模式的 Godot 项目质量保障体系：以 GdUnit4 单元测试为事实检验器，配合 GitHub Actions 流水线，把 AI 的不可预测性变成机器可自动捕获的确定性输出。

### 1. 核心论断

- **AI 不是可信方。** AI 能写出 99% 边界都正确的代码，但剩下 1% 的逻辑幻觉可能是致命的。AI 自己无法察觉这一点。
- **单元测试 = 可执行的规约。** 你先定义“正确的行为”（测试用例），再让 AI 生成能通过测试的代码。这把模糊的自然语言需求变成了机器能判定的 yes/no。
- **CI = 强制化的流水线。** 每次提交自动跑所有测试，失败即阻断。这把“审查”从人的心智负担变成机器的自动工作。

**标准工作流闭环：**

1. 开发者定义任务 → 先写 / 补充测试用例
2. AI 在规范的模块目录里生成代码
3. 本地用 `godot --headless --run-tests` 验证
4. 推送到特性分支，触发 GitHub Actions 全量测试 + 构建
5. 测试失败 → 提取错误日志 → 存入向量错误知识库（见同目录 `issues.md`）→ 开发者或 AI 修复
6. 测试通过 → 合并回 dev → 最终合入 main 并发布

### 2. 中途引入 CI/CD 的四步平滑迁移方案

> 不要一上来就追求"完美测试覆盖"。目标是：**主干稳定，逐步收紧。**

**第一步：基建 — 确保能在 headless 模式下构建**
确认所有代码已入库、`.gitignore` 排除 `import-data/` 和本地构建产物，能用 `godot --headless --export-release "Windows Desktop" build/windows/game.exe` 成功导出。

**第二步：搭流水线骨架 — GitHub Actions**
用社区 `barichello/godot-ci` Docker 镜像创建 `.github/workflows/main.yml`，初版目标就一个：**推送 → 成功构建**。增强版（含测试、多平台构建、部署）见第 4 节。

**第三步：先测核心逻辑**
- 测试框架选 **GdUnit4**。
- **对新功能 / 重大修改强制执行 TDD：** 先写测试 → 看它失败 → 让 AI 写代码让它通过。
- **对遗留代码圈定高价值目标：** AI 状态机逻辑、核心数据结构算法、外部服务交互。先测这些模块的公共接口，其它暂缓。

**第四步：逐步扩大覆盖**
- 利用"童子军规则"：每次修 bug 顺手补一条测试。
- 设置分支保护：PR 必须过 CI 才能合并到 `main`。

### 3. GdUnit4 单元测试实战模板

**为什么选 GdUnit4：** 专为 Godot 4 设计；命令行生成 JUnit XML / HTML 报告（CI 可读）；成熟的 mock / spy 能力隔离测试对象；原生 `await` 支持异步与信号测试；链式断言 API。

**核心原则：测试先写，代码后补。** AI 看到一个失败的测试比听到一段自然语言描述更精确。测试即契约。

#### 3.1 TDD 模板 — AI 状态机行为

```gdscript
# test_pet_ai.gd
# extends GdUnitTestSuite

var pet_ai: PetAI

func before_test():
    pet_ai = PetAI.new()

@test
func test_should_enter_finding_food_state_when_hunger_is_low():
    pet_ai.set_hunger(19)                   # Arrange
    pet_ai.update(0.1)                      # Act
    assert_str(pet_ai.current_state_name()).is_equal_to("FindingFood")  # Assert
```

> 让 AI 写实现代码时直接给它看："让这个测试通过"。它必须写一个能通过的 `PetAI` 类，而不是写一段看似合理却有逻辑漏洞的代码。

#### 3.2 参数化测试 — 系统性覆盖边界情况

AI 特别容易在 null、超长字符串、未知键这类边界上出错。用参数化测试一次覆盖。

```gdscript
# test_affection.gd
# extends GdUnitTestSuite

@test
@it.each([
    ["pat_head", 10],      # 正常输入
    ["give_treat", 25],
    ["", 0],               # 空字符串
    [null, 0],             # null
    ["unknown_action", 0], # 未知动作
    ["a" * 1000, 0],       # 超长输入
])
func test_calculate_affection_gain(interaction_type, expected_gain):
    var gain = AffectionCalculator.calculate_affection_gain(interaction_type)
    assert_int(gain).is_equal(expected_gain)
```

> 一份测试 = 6 次执行，系统性覆盖边界。

#### 3.3 Mock 隔离 — 状态机测试无需实例化整个场景

用 `mock(Node)` 创建假的 `pet_node`，精确控制外部属性，只测状态机逻辑，不测动画、声音：

```gdscript
# test_pet_state_machine.gd
# extends GdUnitTestSuite

var state_machine
var pet_node # 模拟的宠物节点

func before_test():
    # 使用GdUnit的模拟功能创建一个假的宠物节点
    pet_node = mock(Node).return_value()
    # 模拟一些宠物的属性
    when(pet_node.get_hunger).call(func(): return 50)
    when(pet_node.get_energy).call(func(): return 80)

    state_machine = PetStateMachine.new(pet_node)

@test
func test_initial_state_is_idle():
    assert_str(state_machine.get_current_state_name()).is_equal_to("Idle")

@test
func test_transitions_from_idle_to_sleepy_when_energy_is_low():
    # Arrange: 修改模拟节点的返回值，模拟能量降低
    when(pet_node.get_energy).call(func(): return 10)

    # Act: 触发状态机更新
    state_machine.update(0.1)

    # Assert: 验证状态是否正确转移
    assert_str(state_machine.get_current_state_name()).is_equal_to("Sleepy")

@test
func test_does_not_transition_if_conditions_not_met():
    # Arrange: 确保所有转换条件都不满足
    when(pet_node.get_energy).call(func(): return 90)
    when(pet_node.get_hunger).call(func(): return 90)

    # Act
    state_machine.update(0.1)

    # Assert: 状态应该保持不变
    assert_str(state_machine.get_current_state_name()).is_equal_to("Idle")
```

**要点：** mock 隔离外部条件 → 只验证状态转移 → 测试与具体场景实现解耦，速度更快、更稳定。

#### 3.4 场景结构校验 — 防止 AI 改错 `.tscn`

动态加载场景并断言节点存在，CI 环境即可跑，无需人工打开编辑器检查：

```gdscript
# test_pet_scene.gd
# extends GdUnitTestSuite

const PET_SCENE = preload("res://pet.tscn")

@test
func test_pet_scene_has_required_nodes():
    var pet_instance = PET_SCENE.instantiate()
    assert_that(pet_instance.get_node_or_null("AnimationPlayer")).is_not_null()
    assert_that(pet_instance.get_node_or_null("Sprite2D/CollisionArea/CollisionShape2D")).is_not_null()
    assert_that(pet_instance.get_node("AnimationPlayer")).is_instance_of(AnimationPlayer)
    pet_instance.free()
```

#### 3.5 UI / 桌面交互测试的三层策略

| 策略 | 做法 | 适用场景 |
|------|------|----------|
| **首选：逻辑与表现分离** | 把输入处理抽出纯脚本类，只测试它是否发出正确的 signal | 所有可自动化的交互（拖拽、点击、键盘） |
| **次选：原生 UI 自动化** | 用 GdUnit4 的场景模拟能力或社区 UI 测试框架 | 必须测真实 UI 状态 |
| **最后手段：外部桌面自动化** | PyAutoGUI 等，依赖真实屏幕 | 极少量端到端关键路径，**不要进 CI** |

核心原则：**只测交互逻辑，不测视觉表现。** 输入脚本发出 `pet_dragged` / `pet_clicked` 信号即通过，至于动画播不播交给人工或集成测试。

```gdscript
@test
func test_dragging_emits_dragged_signal():
    var pet_input_handler = PetInputHandler.new()

    # 模拟一个输入事件
    var drag_event = InputEventMouseButton.new()
    drag_event.button_index = MOUSE_BUTTON_LEFT
    drag_event.pressed = true
    # ... 设置位置等

    # 使用GdUnit的信号断言来验证信号是否被正确发出
    assert_signal(pet_input_handler.pet_dragged).is_emitted()

    # Act: 将模拟事件传递给处理程序
    pet_input_handler._input(drag_event)

    # ... 模拟拖动和释放过程
    assert_signal(pet_input_handler.pet_dragged).is_emitted()
```

> 完全在 Godot 引擎内部完成，不依赖外部 UI，可在 CI 环境中稳定执行。

### 4. GitHub Actions 流水线骨架

完整的"测试 → 构建 → 部署"流水线模板。关键步骤：

1. **拉取代码**（`fetch-depth: 0`，GdUnit4 需要 git 历史）
2. **下载 Godot 导出模板**
3. **运行所有 GdUnit4 测试**（失败时继续下一步以便上传报告分析）
4. **上传测试报告**（CI Artifact）
5. **构建产物**（Windows / Web）
6. **上传构建产物**
7. **可选部署到 itch.io**（`main` 分支 push 时触发，需要在 Secrets 配置 `ITCHIO_API_KEY`）

```yaml
# .github/workflows/main.yml
name: Godot CI/CD - Test, Build, Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-and-build:
    name: Run Tests & Build Project
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.2.2

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Godot Export Templates
        run: |
          mkdir -p ~/.local/share/godot/export_templates/
          wget https://github.com/godotengine/godot/releases/download/4.2.2-stable/Godot_v4.2.2-stable_export_templates.tpz
          unzip Godot_v4.2.2-stable_export_templates.tpz
          mv templates/* ~/.local/share/godot/export_templates/4.2.2.stable/

      - name: Run GdUnit4 Tests
        run: |
          godot --headless --run-tests --test-suite=res://addons/gdUnit4/src/core/GdUnit4.gd --reports="junit" --report-dir=test-reports
        continue-on-error: true

      - name: Upload Test Reports
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: gdunit-test-reports
          path: test-reports

      - name: Build for Windows
        run: |
          mkdir -p build/windows
          godot --headless --export-release "Windows Desktop" build/windows/game.exe

      - name: Build for Web
        run: |
          mkdir -p build/web
          godot --headless --export-release "Web" build/web/index.html

      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: game-builds
          path: |
            build/windows
            build/web

  deploy-to-itchio:
    name: Deploy to Itch.io
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: test-and-build
    runs-on: ubuntu-latest
    steps:
      - name: Download Build Artifacts
        uses: actions/download-artifact@v2
        with:
          name: game-builds

      - name: Deploy to Itch.io using Butler
        uses: josephbmanley/butler-publish-itchio-action@v1.0.3
        with:
          api_key: ${{ secrets.ITCHIO_API_KEY }}
          user: your-itch-username
          game: your-game-name
          channel: windows-latest
          package: windows/game.exe
```

### 5. AI 与 CI 的深度协同

**模式一：CI 失败 → AI 自动生成修复 PR（现实可落地）**

CI 测试失败时，额外的步骤捕获：失败测试名 + 错误日志 + 相关源码 → 调用 LLM API（GPT-4 / Claude 等），Prompt 中提供：

- 项目上下文（Godot 4 + GDScript）
- 失败的 GdUnit4 测试代码
- 被测试的源代码
- CI 错误日志

要求 AI 只返回修复后的代码块。拿到结果后自动创建 PR，标题格式：`[AI-FIX] Attempt to fix failing test: <test_name>`。

**模式二：AI Agent 全流程自修复（长期方向）**

Agent 拥有对代码库和 CI 的读写权限：监控失败 → 诊断问题（理解项目上下文、运行本地测试、加 print 定位）→ 在特性分支上迭代修复直到 CI 变绿 → 提交带详细解释的 PR。

> 现阶段以模式一为目标即可，不要在基础设施不完善时追求模式二。

### 6. 测试报告：人类可读的信任桥梁

GdUnit4 输出两类报告：

- **JUnit XML**（给机器）：GitHub Actions 解析后在 UI 上展示通过 / 失败数量与耗时
- **HTML**（给人）：完整的测试套件、用例、断言详情。作为 CI Artifact 上传，随时下载查看

**一份全绿的测试报告 = 信任契约**。无论代码内部实现多么奇特，只要外部行为 100% 符合预定义规约，审查的焦点就从"读代码"转移到了"审规约"。这就是降低 AI 审查负担的本质。

---

> 关于"错误记忆系统"（向量知识库 ChromaDB）的使用方法，见同目录 `issues.md`。建议每次 CI 失败后，把错误信息存入向量库，下次 AI 遇到相似症状时可以主动检索历史解决方案。
