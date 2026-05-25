## PetConfig - 桌宠配置管理器
## =========================================================================
## 【架构定位】
##   本类是桌宠应用的配置持久化系统，负责所有用户可调参数的
##   加载、保存和默认值管理。它继承 RefCounted 作为纯数据层，
##   不包含任何UI逻辑，只专注于配置数据的读写。
##
## 【设计模式】
##   采用"数据访问对象（DAO）"模式——将配置文件的底层读写操作
##   封装到本类中，对外暴露简洁的属性访问接口。上层（如
##   settings_window.gd）只需读写属性，无需关心文件I/O细节。
##
## 【核心职责】
##   1. 配置文件的加载与保存（使用Godot内置的ConfigFile类）
##   2. 配置参数的默认值定义与运行时读写
##   3. 配置参数的合法范围校验（如缩放倍率限制在0.2~4.0）
##
## 【配置文件策略】
##   - config_path: 项目内置默认配置（只读，随打包分发）
##   - save_path: 用户个性化配置（读写，保存在user://目录下）
##   加载时优先读取 save_path（用户配置），不存在时回退到 config_path（默认）。
##   保存时始终写入 save_path。
##
## 【配置结构】（pet_config.cfg）
##   [pet]
##     scale = 1.0              # 精灵缩放倍率 (0.2 ~ 4.0)
##     material_preset = "slime_1"  # 当前选中的材质预设id
##   [window]
##     initial_x = -1           # 窗口初始X坐标（-1表示使用默认位置）
##     initial_y = -1           # 窗口初始Y坐标（-1表示使用默认位置）
##     always_on_top = true     # 窗口是否始终置顶
##   [autostart]
##     enabled = false          # 是否开机自启动
## =========================================================================

extends RefCounted

## Godot内置的配置文件读写器
## ConfigFile是Godot引擎提供的INI风格配置文件解析器
var config: ConfigFile = ConfigFile.new()

## 默认配置文件路径（项目内置，随打包分发，只读）
## 使用 res:// 前缀表示这是项目资源路径
var config_path: String = "res://data/pet_config.cfg"

## 用户配置文件路径（保存用户个性化设置，可读写）
## 使用 user:// 前缀表示用户数据目录，不同OS下路径不同：
##   Windows: %APPDATA%\Godot\app_userdata\{project_name}
##   Linux: ~/.local/share/godot/app_userdata/{project_name}
##   macOS: ~/Library/Application Support/Godot/app_userdata/{project_name}
var save_path: String = "user://pet_config.cfg"

## =========================================================================
## [pet] 栏目 —— 桌宠相关配置
## =========================================================================

## 桌宠精灵的缩放倍率
## 取值范围：0.2（最小，20%大小）~ 4.0（最大，400%大小）
## 默认值 1.0 表示原始大小（100%）
var pet_scale: float = 1.0

## 当前使用的材质预设id
## 默认值 "slime_1" 对应 "1号史莱姆(普通)" 预设
## 该id用于从 MaterialRegistry 中查找对应的材质配置
var material_preset: String = "slime_1"

## =========================================================================
## [window] 栏目 —— 窗口相关配置
## =========================================================================

## 窗口初始X坐标（屏幕坐标像素）
## -1 表示使用系统默认位置（由操作系统决定窗口出现的位置）
## >= 0 的值表示窗口左上角的屏幕X坐标
var window_initial_x: int = -1

## 窗口初始Y坐标（屏幕坐标像素）
## 与 window_initial_x 配合使用，共同决定窗口的初始位置
var window_initial_y: int = -1

## 窗口是否始终置顶（Always On Top）
## true: 窗口始终显示在所有其他窗口之上（包括任务栏）
## false: 窗口与其他窗口一样正常堆叠
## 默认 true，使桌宠始终可见
var window_always_on_top: bool = true

## =========================================================================
## [autostart] 栏目 —— 自启动相关配置
## =========================================================================

## 是否开启开机自启动
## true: 向Windows注册表添加启动项，系统启动时自动运行
## false: 不自动启动
## 默认 false，由用户手动开启
var autostart_enabled: bool = false


## 构造函数
## 【核心逻辑】
##   对象创建时立即加载配置，确保配置数据在对象使用的第一时间就可用。
##   这是一种"急切加载（Eager Loading）"策略，避免了懒加载可能带来的
##   首次访问延迟。
func _init():
	load_config()


## 加载配置文件
## 【加载优先级】
##   1. 优先加载 user:// 下的用户个性化配置（save_path）
##   2. 若用户配置不存在，则加载 res:// 下的默认配置（config_path）
##   3. 若两者都不存在/加载失败，使用代码中的硬编码默认值并自动保存
## 【核心逻辑】
##   使用 FileAccess.file_exists() 判断文件是否存在，
##   调用 ConfigFile.load() 读取INI格式的配置文件，
##   然后通过各 _read_*_section() 方法解析各配置段。
## 【边界情况】
##   - 两个配置文件都不存在 → 使用默认值并立即保存一份配置文件
##   - 配置文件存在但解析失败 → 使用默认值
##   - 配置值超出合法范围 → _read_pet_section() 中用 clamp() 限幅
func load_config():
	var err = OK
	if FileAccess.file_exists(save_path):
		err = config.load(save_path)
	else:
		err = config.load(config_path)

	if err == OK:
		_read_pet_section()
		_read_window_section()
		_read_autostart_section()
		print("✅ [配置] 配置文件加载成功")
	else:
		print("⚠️ [配置] 配置文件不存在或加载失败，使用默认值")
		_save_config()


## 读取 [pet] 配置段
## 【读取的配置项】
##   scale: 精灵缩放倍率
##   material_preset: 材质预设id
## 【安全措施】
##   - 使用 config.get_value() 的第三个参数提供默认值
##   - scale 使用 clamp() 限幅到 [0.2, 4.0]，防止异常配置值
##   - material_preset 默认值为 "slime_1"
func _read_pet_section():
	pet_scale = config.get_value("pet", "scale", 1.0)
	pet_scale = clamp(pet_scale, 0.2, 4.0)
	material_preset = config.get_value("pet", "material_preset", "slime_1")


## 读取 [window] 配置段
## 【读取的配置项】
##   initial_x: 窗口初始X坐标
##   initial_y: 窗口初始Y坐标
##   always_on_top: 窗口置顶标志
## 【安全措施】
##   所有值都提供合理的默认值，确保即使配置文件缺失任意字段也不会出错
func _read_window_section():
	window_initial_x = config.get_value("window", "initial_x", -1)
	window_initial_y = config.get_value("window", "initial_y", -1)
	window_always_on_top = config.get_value("window", "always_on_top", true)


## 读取 [autostart] 配置段
## 【读取的配置项】
##   enabled: 自启动开关
## 【安全措施】
##   默认值为 false（不自动启动），这是"安全优于便利"的设计原则
func _read_autostart_section():
	autostart_enabled = config.get_value("autostart", "enabled", false)


## 保存配置到文件（内部方法）
## 【核心逻辑】
##   1. 将所有运行时配置属性写入 config 对象
##   2. 调用 config.save() 持久化到 save_path
##   3. 输出成功/失败日志
## 【为什么分为 _save_config() 和 save_config()？】
##   _save_config() 是内部实现，save_config() 是公共接口。
##   这种封装允许将来在 save_config() 中添加额外的逻辑
##   （如保存前校验、保存后通知等），而不改动内部实现。
## 【边界情况】
##   保存失败时会打印错误但不抛出异常——这是"优雅降级"策略，
##   配置保存失败不应该影响桌宠的正常运行。
func _save_config():
	config.set_value("pet", "scale", pet_scale)
	config.set_value("pet", "material_preset", material_preset)
	config.set_value("window", "initial_x", window_initial_x)
	config.set_value("window", "initial_y", window_initial_y)
	config.set_value("window", "always_on_top", window_always_on_top)
	config.set_value("autostart", "enabled", autostart_enabled)

	var err = config.save(save_path)
	if err == OK:
		print("✅ [配置] 配置文件已保存: ", save_path)
	else:
		printerr("[配置] 配置文件保存失败: ", save_path)


## 保存配置到文件（公共接口）
## 【用途】供外部调用（如设置窗口的保存按钮）
## 【核心逻辑】直接委托给 _save_config()
func save_config():
	_save_config()


## 打印当前所有配置参数到控制台（调试用）
## 【用途】开发调试时查看当前配置状态
## 【格式】树形结构展示，参照项目日志风格
func print_config():
	print("\n📋 [配置] 当前配置参数:")
	print("├── [pet]")
	print("│   ├── scale: ", pet_scale)
	print("│   └── material_preset: ", material_preset)
	print("└── [window]")
	print("    ├── initial_x: ", window_initial_x)
	print("    ├── initial_y: ", window_initial_y)
	print("    └── always_on_top: ", window_always_on_top)
	print("[autostart]")
	print("    └── enabled: ", autostart_enabled)
	print()


## 获取当前材质的显示名称
## 【返回值】 String - 材质预设对应的友好显示名称
## 【当前实现】
##   由于当前仅有一个预设 "slime_1"，直接返回对应名称。
##   将来若有多预设支持，应改为从 MaterialManager 查询。
func get_material_name() -> String:
	return "1号史莱姆(普通)"
