class_name ProjectConstants

# ============================================================================
# core/utils/constants.gd — 全局不可变常量
# ============================================================================
# 本文件仅存放真正不可变的全局常量（路径、硬边界、系统标识）。
# 运行时可通过 .cfg 配置的值（如物理参数、缩放默认值）属于模块级常量，
# 请参见 modules/pet/scripts/pet_constants.gd。
# ============================================================================

# ── 场景/资源路径 ──

## 史莱姆宠物SVG资源路径
const SVG_PATH: String = "res://modules/pet/assets/pet_sprite.svg"
## 液态玻璃渲染器场景路径
const LIQUID_GLASS_SCENE: String = "res://modules/effects/scenes/liquid_glass_renderer.tscn"
## 设置窗口场景路径
const SETTINGS_WINDOW_SCENE: String = "res://modules/settings/ui/settings_window.tscn"
## 抛射参数设置弹窗场景路径
const THROW_DIALOG_SCENE: String = "res://modules/settings/ui/throw_settings_dialog.tscn"

# ── UI 布局 ──

## 设置窗口相对于宠物的弹出偏移量
const SETTINGS_WINDOW_OFFSET := Vector2(50, -130)

# ── 缩放硬边界（UI 校验用，不可通过配置覆盖） ──

## 宠物最小缩放比例（防止缩到看不见）
const PET_SCALE_MIN := 0.2
## 宠物最大缩放比例（防止过大撑满屏幕）
const PET_SCALE_MAX := 4.0

# ── 系统标识 ──

## 应用名称（用于注册表、任务管理器等系统标识）
const APP_NAME: String = "TransparentPet"
## Windows 开机启动注册表路径
const REG_KEY: String = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
