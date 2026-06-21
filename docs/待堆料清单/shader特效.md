# Shader 特效待办

> 所有 Shader 特效相关的待办项目

---

## 待办项目

| Shader           | 用途       | 关联预设  | 优先级 | 备注                   |
| ---------------- | ---------- | --------- | ------ | ---------------------- |
| `metal.gdshader` | 金属史莱姆 | `slime_3` | 高     | 表面反光、金属质感     |
| `ice.gdshader`   | 冰晶史莱姆 | `slime_4` | 高     | 透明、碎玻璃反光效果   |
| `fire.gdshader`  | 火焰史莱姆 | `slime_5` | 高     | 内部流动光效、熔岩质感 |

---

## 如何接入

在 `modules/display/scripts/material_manager.gd` 的 `_get_shader_for_preset()` 中添加分发逻辑：

```gdscript
func _get_shader_for_preset(preset_id: String) -> Resource:
    match preset_id:
        "slime_1":
            return preload("res://modules/display/shaders/slime.gdshader")
        "slime_2":
            return preload("res://modules/liquid_glass/shaders/main.gdshader")
        "slime_3":
            return preload("res://modules/display/shaders/metal.gdshader")
        "slime_4":
            return preload("res://modules/display/shaders/ice.gdshader")
        "slime_5":
            return preload("res://modules/display/shaders/fire.gdshader")
        _:
            return preload("res://modules/display/shaders/slime.gdshader")
```
