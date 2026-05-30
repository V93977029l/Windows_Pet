/*
 * ============================================================================
 * MousePassthrough 类头文件 - Windows 窗口鼠标穿透控制
 * ============================================================================
 *
 * 【项目架构角色】
 *   MousePassthrough 负责控制 Godot 渲染窗口的鼠标穿透（Click-through）属性。
 *   它利用 Windows 的 WS_EX_TRANSPARENT 和 WS_EX_LAYERED 扩展窗口样式，
 *   使窗口在特定像素区域"透明"于鼠标事件——即鼠标点击可以穿过窗口到达
 *   下层应用程序。
 *
 * 【与其他模块的关系】
 *   - 与 SystemTray 配合：SystemTray 管理系统托盘图标，
 *     MousePassthrough 控制窗口的鼠标穿透
 *   - 与液态玻璃渲染配合：在渲染透明/半透明的玻璃效果区域时，
 *     对应的像素应该允许鼠标穿透
 *
 * 【WS_EX_TRANSPARENT 工作原理】
 *   - 设置 WS_EX_TRANSPARENT 后，Windows 在派发鼠标消息时跳过此窗口
 *   - 鼠标事件被传递给 Z 顺序中下方的窗口
 *   - 需要同时设置 WS_EX_LAYERED 才能完全生效（与窗口透明度相关）
 *
 * 【WS_EX_TOOLWINDOW 工作原理】
 *   - 设置后窗口不在任务栏显示
 *   - 清除 WS_EX_APPWINDOW 防止 Windows 将其识别为应用窗口
 *   - 是隐藏桌面宠物类应用任务栏图标的常用手段
 *
 * 【FindWindowW 备用机制】
 *   当用户未直接传入窗口 HWND 时，通过窗口标题使用 FindWindowW 查找。
 *   支持 Godot 调试模式的 "(DEBUG)" 后缀自动识别。
 */

#ifndef MOUSE_PASSTHROUGH_H
#define MOUSE_PASSTHROUGH_H

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/object.hpp>

namespace godot {

/*
 * MousePassthrough 类 - 鼠标穿透控制
 *
 * 提供了给 Godot 脚本的鼠标穿透开启/关闭接口。
 * 核心功能：
 * 1. 启用/禁用全局鼠标穿透
 * 2. 根据像素是否不透明动态切换穿透状态
 * 3. 隐藏窗口任务栏图标
 */
class MousePassthrough : public Object {
    GDCLASS(MousePassthrough, Object);

private:
    /*
     * mouse_passthrough_enabled - 鼠标穿透是否启用（默认 true）
     *   全局开关，当为 false 时所有穿透控制都不生效
     *   调用 update_mouse_passthrough() 时也需要此开关为 true
     *   默认值为 true：符合桌面宠物默认可穿透的预期行为
     */
    bool mouse_passthrough_enabled = true;
    
    /*
     * hide_taskbar - 是否已请求隐藏任务栏图标（默认 false）
     *   用于在 update_mouse_passthrough() 和 reset_mouse_passthrough() 中
     *   保持 WS_EX_TOOLWINDOW 样式设置
     */
    bool hide_taskbar = false;
    
    /*
     * window_handle - 窗口句柄（HWND，默认 0）
     *   使用 uint64_t 类型以适应 64 位指针，同时兼容 GDScript
     *   0 表示未设置，此时会回退到通过窗口标题查找
     */
    uint64_t window_handle = 0;
    
    /*
     * window_title - 窗口标题（备用查找方式）
     *   当 window_handle 为 0 时，通过此标题查找窗口
     *   Godot 在调试模式下会在标题后添加 " (DEBUG)"
     */
    godot::String window_title = "";

protected:
    /*
     * _bind_methods() - 绑定方法到 Godot
     *   将 C++ 方法暴露给 GDScript
     *   详见 mouse_passthrough.cpp 中的实现
     */
    static void _bind_methods();

public:
    MousePassthrough();
    ~MousePassthrough();

    /*
     * set_mouse_passthrough() - 设置鼠标穿透全局开关
     *   enabled: true = 启用穿透控制，false = 禁用（窗口正常接收鼠标事件）
     *
     *   当设置为 false 时，会自动调用 reset_mouse_passthrough()
     *   确保窗口恢复到可接收鼠标事件的状态
     */
    void set_mouse_passthrough(bool enabled);
    
    /*
     * get_mouse_passthrough() - 获取当前鼠标穿透状态
     *   返回：true = 穿透已启用，false = 已禁用
     */
    bool get_mouse_passthrough() const;

    /*
     * set_window_handle() - 直接设置窗口句柄
     *   window_handle: 窗口 HWND 的 uint64_t 表示
     *
     *   优先使用此方法设置 HWND，比通过窗口标题查找更可靠。
     */
    void set_window_handle(uint64_t window_handle);
    
    /*
     * set_window_title() - 设置窗口标题（备用查找方式）
     *   window_title: Godot 窗口的标题文本
     *
     *   仅在 window_handle 为 0 时生效。
     *   支持查找带 "(DEBUG)" 后缀的调试模式标题。
     */
    void set_window_title(const godot::String& window_title);
    
    /*
     * update_mouse_passthrough() - 更新鼠标穿透状态
     *   has_opaque_pixel: 当前鼠标位置是否有不透明像素
     *
     *   核心逻辑：
     *   - has_opaque_pixel == true：窗口内容不透明 → 禁用穿透（可以点击）
     *   - has_opaque_pixel == false：窗口内容透明 → 启用穿透（点击穿过）
     *
     *   此方法通常每帧调用一次，与渲染逻辑配合使用：
     *   检测鼠标悬停区域的像素是否不透明，决定是否允许鼠标通过。
     */
    void update_mouse_passthrough(bool has_opaque_pixel);
    
    /*
     * reset_mouse_passthrough() - 重置鼠标穿透状态
     *
     *   清除 WS_EX_TRANSPARENT 标志，使窗口恢复正常的鼠标事件接收。
     *   通常在：
     *   - 关闭穿透功能时
     *   - 插件销毁时
     *   调用此方法。
     */
    void reset_mouse_passthrough();

    /*
     * hide_taskbar_icon() - 隐藏任务栏图标
     *
     *   通过设置 WS_EX_TOOLWINDOW 扩展样式使窗口不在任务栏显示。
     *   同时清除 WS_EX_APPWINDOW 样式。
     *   设置 hide_taskbar 标志，后续的 update/reset 操作会自动维持此状态。
     */
    void hide_taskbar_icon();
};

} // namespace godot

#endif // MOUSE_PASSTHROUGH_H
