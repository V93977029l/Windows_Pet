#ifndef MOUSE_PASSTHROUGH_H
#define MOUSE_PASSTHROUGH_H

// 包含godot-cpp的核心头文件
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/object.hpp>

namespace godot {

/**
 * @class MousePassthrough
 * @brief 鼠标穿透插件类
 * 
 * 该类提供了给Godot脚本的鼠标穿透的开启和关闭接口
 */
class MousePassthrough : public Object {
    GDCLASS(MousePassthrough, Object);

private:
    /**
     * @brief 鼠标穿透是否启用
     */
    bool mouse_passthrough_enabled = true;
    
    /**
     * @brief 窗口句柄
     */
    uint64_t window_handle = 0;
    
    /**
     * @brief 窗口标题
     */
    godot::String window_title = "";

protected:
    /**
     * @brief 绑定方法到Godot
     */
    static void _bind_methods();

public:
    /**
     * @brief 构造函数
     */
    MousePassthrough();
    
    /**
     * @brief 析构函数
     */
    ~MousePassthrough();

    /**
     * @brief 设置鼠标穿透状态
     * 
     * @param enabled 是否启用鼠标穿透
     */
    void set_mouse_passthrough(bool enabled);
    
    /**
     * @brief 获取鼠标穿透状态
     * 
     * @return bool 当前鼠标穿透状态
     */
    bool get_mouse_passthrough() const;

    /**
     * @brief 设置窗口句柄
     * 
     * @param window_handle 窗口句柄
     */
    void set_window_handle(uint64_t window_handle);
    
    /**
     * @brief 设置窗口标题
     * 
     * @param window_title 窗口标题
     */
    void set_window_title(const godot::String& window_title);
    
    /**
     * @brief 更新鼠标穿透状态
     * 
     * @param has_opaque_pixel 是否有不透明像素（鼠标是否在精灵上）
     * 
     * 当has_opaque_pixel为true时，禁用鼠标穿透（窗口不可穿透）
     * 当has_opaque_pixel为false时，启用鼠标穿透（窗口可以穿透）
     */
    void update_mouse_passthrough(bool has_opaque_pixel);
    
    /**
     * @brief 重置鼠标穿透状态
     * 
     * 禁用鼠标穿透，确保窗口可以接收鼠标事件
     */
    void reset_mouse_passthrough();
};

} // namespace godot

#endif // MOUSE_PASSTHROUGH_H