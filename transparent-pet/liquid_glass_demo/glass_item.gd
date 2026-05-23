class_name GlassItem

enum ShapeType {
    CIRCLE = 0,
    ROUNDED_RECT = 1,
    SLIME = 2
}

@export var position: Vector2 = Vector2.ZERO
@export var width: float = 200.0
@export var height: float = 200.0
@export var radius: float = 80.0
@export var roundness: float = 5.0
@export var shape_type: ShapeType = ShapeType.ROUNDED_RECT
@export var enabled: bool = true
@export var scale: float = 1.0

func _init():
    pass

func _init_from_dict(data: Dictionary):
    if data.has("position"):
        position = data.position
    if data.has("width"):
        width = data.width
    if data.has("height"):
        height = data.height
    if data.has("radius"):
        radius = data.radius
    if data.has("roundness"):
        roundness = data.roundness
    if data.has("shape_type"):
        shape_type = data.shape_type
    if data.has("enabled"):
        enabled = data.enabled
    if data.has("scale"):
        scale = data.scale

func to_shader_params() -> Dictionary:
    return {
        "position": position,
        "width": width,
        "height": height,
        "radius": radius,
        "roundness": roundness,
        "shape_type": float(shape_type),
        "enabled": 1.0 if enabled else 0.0,
        "scale": scale
    }

func get_bounding_rect() -> Rect2:
    var half_width = (width * scale) / 2.0
    var half_height = (height * scale) / 2.0
    return Rect2(
        position - Vector2(half_width, half_height),
        Vector2(width * scale, height * scale)
    )

func contains_point(point: Vector2) -> bool:
    return get_bounding_rect().has_point(point)