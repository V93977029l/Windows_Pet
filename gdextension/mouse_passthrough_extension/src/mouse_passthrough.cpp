#include "mouse_passthrough.h"
#include <cstdio>
#include <cstdint>

// 包含godot-cpp的核心头文件
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/variant/variant.hpp>

// Windows API headers
#ifdef _WIN32
#include <windows.h>
#endif

namespace godot {

/**
 * @brief MousePassthrough类构造函数
 * 
 * 初始化鼠标穿透插件，打印创建信息
 */
MousePassthrough::MousePassthrough() {
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 初始化插件"));
    // 暂时不在构造函数中设置穿透状态，等待窗口完全创建后再设置
}

/**
 * @brief MousePassthrough类析构函数
 * 
 * 销毁鼠标穿透插件，重置鼠标穿透状态
 */
MousePassthrough::~MousePassthrough() {
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 销毁插件"));
    reset_mouse_passthrough();
}

/**
 * @brief 设置窗口句柄
 * 
 * @param window_handle 窗口句柄
 */
void MousePassthrough::set_window_handle(uint64_t window_handle) {
    this->window_handle = window_handle;
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 设置窗口句柄: ") + godot::String::num_uint64(window_handle));
}

/**
 * @brief 设置窗口标题
 * 
 * @param window_title 窗口标题
 */
void MousePassthrough::set_window_title(const godot::String& window_title) {
    this->window_title = window_title;
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 设置窗口标题: ") + window_title);
}

/**
 * @brief 设置鼠标穿透状态
 * 
 * @param enabled 是否启用鼠标穿透
 */
void MousePassthrough::set_mouse_passthrough(bool enabled) {
    mouse_passthrough_enabled = enabled;
    if (!enabled) {
        reset_mouse_passthrough();
    }
}

/**
 * @brief 获取鼠标穿透状态
 * 
 * @return bool 当前鼠标穿透状态
 */
bool MousePassthrough::get_mouse_passthrough() const {
    return mouse_passthrough_enabled;
}

/**
 * @brief 更新鼠标穿透状态
 * 
 * @param has_opaque_pixel 是否有不透明像素
 * 
 * 当has_opaque_pixel为true时，禁用鼠标穿透（窗口不可穿透）
 * 当has_opaque_pixel为false时，启用鼠标穿透（窗口可以穿透）
 */
void MousePassthrough::update_mouse_passthrough(bool has_opaque_pixel) {
    // 检查鼠标穿透是否启用
    if (!mouse_passthrough_enabled) {
        return;
    }

#ifdef _WIN32
    // 使用存储的窗口句柄
    HWND hwnd = nullptr;
    
    if (window_handle == 0) {
        // 尝试通过标题获取窗口句柄
        if (!window_title.is_empty()) {
            hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
            if (hwnd == nullptr) {
                // 尝试添加DEBUG后缀
                godot::String debug_title = window_title + " (DEBUG)";
                hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
            }
        }
    } else {
        hwnd = (HWND)window_handle;
    }
    
    if (hwnd == nullptr) {
        godot::print_line(godot::String::utf8("[插件:鼠标穿透] 未找到窗口句柄"));
        return;
    }
    
    // 获取当前窗口样式
    LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);

    if (has_opaque_pixel) {
        // 禁用鼠标穿透
        godot::print_line(godot::String::utf8("[插件:鼠标穿透] 禁用鼠标穿透"));
        ex_style &= ~WS_EX_TRANSPARENT;
    } else {
        // 启用鼠标穿透
        godot::print_line(godot::String::utf8("[插件:鼠标穿透] 启用鼠标穿透"));
        ex_style |= WS_EX_TRANSPARENT;
        ex_style |= WS_EX_LAYERED;
    }
    
    // 设置新的窗口样式
    LONG result = SetWindowLong(hwnd, GWL_EXSTYLE, ex_style);
    
    if (result != 0) {
        // 更新窗口以应用更改
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
        godot::print_line(godot::String::utf8("✅更新成功"));
    } else {
        godot::print_line(godot::String::utf8("❌更新失败"));
    }
#endif
}

/**
 * @brief 重置鼠标穿透状态
 * 
 * 禁用鼠标穿透，确保窗口可以接收鼠标事件
 */
void MousePassthrough::reset_mouse_passthrough() {
#ifdef _WIN32
    // 使用存储的窗口句柄
    HWND hwnd = nullptr;
    
    if (window_handle == 0) {
        // 尝试通过标题获取窗口句柄
        if (!window_title.is_empty()) {
            hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
            if (hwnd == nullptr) {
                // 尝试添加DEBUG后缀
                godot::String debug_title = window_title + " (DEBUG)";
                hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
            }
        }
    } else {
        hwnd = (HWND)window_handle;
    }
    
    if (hwnd == nullptr) {
        godot::print_line(godot::String::utf8("[插件:鼠标穿透] 未找到窗口句柄，无法重置鼠标穿透"));
        return;
    }
    
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 重置鼠标穿透状态"));
    
    // 禁用鼠标穿透
    LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
    ex_style &= ~WS_EX_TRANSPARENT;
    SetWindowLong(hwnd, GWL_EXSTYLE, ex_style);
    
    // 更新窗口以应用更改
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 鼠标穿透状态已重置"));
#endif
}

/**
 * @brief 绑定方法到Godot
 * 
 * 将C++方法绑定到Godot，使其可以在GDScript中调用
 */
void MousePassthrough::_bind_methods() {
    // 绑定set_mouse_passthrough方法
    ClassDB::bind_method(D_METHOD("set_mouse_passthrough", "enabled"), &MousePassthrough::set_mouse_passthrough);
    
    // 绑定get_mouse_passthrough方法
    ClassDB::bind_method(D_METHOD("get_mouse_passthrough"), &MousePassthrough::get_mouse_passthrough);
    
    // 绑定set_window_handle方法
    ClassDB::bind_method(D_METHOD("set_window_handle", "window_handle"), &MousePassthrough::set_window_handle);
    
    // 绑定set_window_title方法
    ClassDB::bind_method(D_METHOD("set_window_title", "window_title"), &MousePassthrough::set_window_title);
    
    // 绑定update_mouse_passthrough方法，简化参数，只需要has_opaque_pixel
    ClassDB::bind_method(D_METHOD("update_mouse_passthrough", "has_opaque_pixel"), &MousePassthrough::update_mouse_passthrough);
    
    // 绑定reset_mouse_passthrough方法
    ClassDB::bind_method(D_METHOD("reset_mouse_passthrough"), &MousePassthrough::reset_mouse_passthrough);

    // 添加mouse_passthrough属性
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "mouse_passthrough"), "set_mouse_passthrough", "get_mouse_passthrough");
}

} // namespace godot