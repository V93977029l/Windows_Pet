# ============================================================================
# modules/pet/scripts/pet_constants.gd — Pet 模块的 .cfg 配置默认值
# ============================================================================
# 这些常量是 ConfigManager.cfg_get() 的 fallback 默认值。
# 它们的真实来源是 export/ 目录下的 .cfg 配置文件。
# 运行时通过 ConfigManager 读取，此处的常量仅在 .cfg 缺失对应键时生效。
# ============================================================================

# ── 宠物缩放 ──

## 宠物默认缩放比例（原始大小）
const PET_SCALE_DEFAULT := 1.0
## 高清渲染时的最小缩放阈值（低于此值切换低精度渲染）
const HIGH_RES_SCALE_MIN := 0.1

# ── 抛射物理 ──

## 默认重力加速度（像素/秒²，模拟下落感）
const THROW_GRAVITY_DEFAULT := 800.0
## 触发抛射的最小拖动速度（像素/秒，低于此值不触发弹射）
const THROW_MIN_SPEED_DEFAULT := 350.0
## 抛射速度上限（像素/秒，防止飞出屏幕外太远）
const THROW_MAX_SPEED_DEFAULT := 800.0
## 拖动速度→抛射速度的倍率系数
const THROW_MULTIPLIER_DEFAULT := 2.0
## 抛射功能总开关（默认开启）
const THROW_ENABLED_DEFAULT := true

# ── 碰撞/反弹物理 ──

## 落地反弹系数（0-1，越小弹力越弱）
const PHYSICS_GROUND_BOUNCE_DEFAULT := 0.3
## 撞墙反弹系数（0-1，越小弹力越弱）
const PHYSICS_WALL_BOUNCE_DEFAULT := 0.7
## 接地摩擦力（像素/秒²，停止水平滑动的阻力度）
const PHYSICS_GROUND_FRICTION_DEFAULT := 500.0
## 安全网阈值（像素，超出屏幕底部此距离后强制停止弹射）
const PHYSICS_FALL_THRESHOLD_DEFAULT := 500.0

# ── SVG 碰撞盒估算 ──

## SVG半宽比例（用于碰撞检测时估算精灵宽度）
const SVG_HALF_W_RATIO_DEFAULT := 0.4
## SVG底部偏移比例（用于碰撞检测时估算精灵底部位置）
const SVG_BOTTOM_OFFSET_RATIO_DEFAULT := 0.417
## SVG碰撞盒降级宽度（贴图加载失败时的后备值，单位：像素）
const SVG_FALLBACK_SIZE_X_DEFAULT := 200
## SVG碰撞盒降级高度（贴图加载失败时的后备值，单位：像素）
const SVG_FALLBACK_SIZE_Y_DEFAULT := 132

# ── 拖动速度缓冲区 ──

## 速度缓冲区大小（用于平滑拖动→抛射的速度计算，帧数越多越平滑但响应越慢）
const VELOCITY_BUFFER_SIZE_DEFAULT: int = 8

# ── 窗口行为 ──

## 窗口默认是否置顶
const WINDOW_ALWAYS_ON_TOP_DEFAULT := true
## 启动时是否自动打开设置窗口
const WINDOW_OPEN_SETTINGS_DEFAULT := true
## 开机自启动默认行为（默认关闭）
const WINDOW_AUTOSTART_DEFAULT := false
