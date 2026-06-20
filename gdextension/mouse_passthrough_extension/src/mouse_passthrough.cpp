/*
 * ============================================================================
 * MousePassthrough 类实现 - Windows 窗口鼠标穿透控制
 * ============================================================================
 *
 * 【实现概述】
 *   本文件实现了基于 Win32 窗口扩展样式的鼠标穿透控制功能。
 *   核心原理是通过设置/清除 WS_EX_TRANSPARENT 和 WS_EX_LAYERED
 *   扩展窗口样式，控制鼠标事件是否穿透窗口。
 *
 * 【Windows 扩展窗口样式说明】
 *   使用 GetWindowLong/SetWindowLong 读取/修改窗口的 GWL_EXSTYLE：
 *   - WS_EX_TRANSPARENT (0x00000020): 窗口对鼠标透明
 *       鼠标消息跳过此窗口，传递给下层的窗口
 *   - WS_EX_LAYERED (0x00080000): 分层窗口
 *       配合 WS_EX_TRANSPARENT 使用，支持像素级透明度
 *   - WS_EX_TOOLWINDOW (0x00000080): 工具窗口样式
 *       窗口不显示在任务栏和 Alt+Tab 列表中
 *   - WS_EX_APPWINDOW (0x00040000): 应用程序窗口样式
 *       需要清除以确保 WS_EX_TOOLWINDOW 生效
 *
 * 【SetWindowPos 说明】
 *   SetWindowPos 用于应用窗口样式更改：
 *   - SWP_NOMOVE: 不改变窗口位置
 *   - SWP_NOSIZE: 不改变窗口大小
 *   - SWP_NOZORDER: 不改变 Z 顺序
 *   - SWP_FRAMECHANGED: 通知系统窗口框架已更改（强制重绘）
 *   - SWP_NOACTIVATE: 不激活窗口
 *
 *   组合使用这些标志的目的是"仅更新窗口样式，不改变外观状态"。
 */

#include "mouse_passthrough.h"
#include <cstdint>
#include <cstdio>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/variant.hpp>

#ifdef _WIN32
#include <windows.h>
#endif

namespace godot
{

/*
 * 构造函数
 *   输出初始化日志
 *   不在构造函数中设置穿透状态，等待窗口完全创建后再设置
 *   原因是：构造时 Godot 的主窗口可能尚未创建完成
 */
MousePassthrough::MousePassthrough()
{
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 初始化插件"));
}

/*
 * 析构函数
 *   调用 reset_mouse_passthrough() 清除 WS_EX_TRANSPARENT
 *   确保插件销毁后窗口恢复正常鼠标事件接收能力
 */
MousePassthrough::~MousePassthrough()
{
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 销毁插件"));
    reset_mouse_passthrough();
}

/*
 * set_window_handle() - 设置窗口句柄
 *   直接保存 HWND 供后续操作使用
 *   优先于通过窗口标题查找的方式
 */
void MousePassthrough::set_window_handle(uint64_t window_handle)
{
    this->window_handle = window_handle;
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 设置窗口句柄: ") + godot::String::num_uint64(window_handle));
}

/*
 * set_window_title() - 设置窗口标题
 *   作为当 window_handle 为 0 时的备用查找方式
 */
void MousePassthrough::set_window_title(const godot::String& window_title)
{
    this->window_title = window_title;
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 设置窗口标题: ") + window_title);
}

/*
 * set_mouse_passthrough() - 设置全局穿透开关
 *   enabled = false: 立即调用 reset_mouse_passthrough() 恢复正常状态
 *   enabled = true: 允许后续的 update 操作生效
 */
void MousePassthrough::set_mouse_passthrough(bool enabled)
{
    mouse_passthrough_enabled = enabled;
    if (!enabled) {
        reset_mouse_passthrough();
    }
}

bool MousePassthrough::get_mouse_passthrough() const
{
    return mouse_passthrough_enabled;
}

/*
 * update_mouse_passthrough() - 根据像素透明度动态更新穿透状态
 *
 * 这是每帧调用的核心函数。它检测当前鼠标位置是否有不透明像素，
 * 并据此动态切换窗口的穿透属性。
 *
 * 流程（4个步骤）：
 *
 * 步骤1：检查全局开关
 *   如果 mouse_passthrough_enabled 为 false，直接返回
 *   确保在用户禁用穿透时不会意外启用
 *
 * 步骤2：获取窗口 HWND
 *   优先级：直接设置的 handle > 通过标题查找 > 失败返回
 *   标题查找策略：
 *   a) 先查找原始标题
 *   b) 再查找带 "(DEBUG)" 后缀的标题（Godot 调试模式自动添加）
 *   如果都找不到，静默返回（不报错，等待下次调用）
 *
 * 步骤3：读取并修改窗口扩展样式
 *   GetWindowLong(hwnd, GWL_EXSTYLE) 读取当前样式
 *
 *   has_opaque_pixel == true（有内容）：
 *     ex_style &= ~WS_EX_TRANSPARENT;  // 清除穿透标志
 *     → 窗口正常接收鼠标事件
 *
 *   has_opaque_pixel == false（透明区域）：
 *     ex_style |= WS_EX_TRANSPARENT;   // 设置穿透标志
 *     ex_style |= WS_EX_LAYERED;       // 设置分层窗口标志
 *     → 鼠标事件穿透到下层窗口
 *
 *   同时检查 hide_taskbar 标志：
 *     hide_taskbar == true：
 *       ex_style |= WS_EX_TOOLWINDOW;
 *       ex_style &= ~WS_EX_APPWINDOW;
 *     → 保持任务栏图标隐藏
 *
 * 步骤4：应用样式更改
 *   SetWindowLong(hwnd, GWL_EXSTYLE, ex_style) 写入新样式
 *   如果写入成功（result != 0）：
 *     SetWindowPos(hwnd, nullptr, 0,0,0,0,
 *       SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED)
 *     → 强制系统重新评估窗口的非客户区（NC area）
 *
 * 性能注意：
 *   此函数每帧都调用，因此 HWND 查找逻辑设计了缓存机制：
 *   如果 window_handle 不为 0，直接使用；否则每次重新查找。
 *   建议在窗口创建后通过 set_window_handle() 设置句柄以避免重复查找。
 */
void MousePassthrough::update_mouse_passthrough(bool has_opaque_pixel)
{
    if (!mouse_passthrough_enabled) {
        return;
    }

#ifdef _WIN32
    HWND hwnd = nullptr;

    if (window_handle == 0) {
        if (!window_title.is_empty()) {
            hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
            if (hwnd == nullptr) {
                godot::String debug_title = window_title + " (DEBUG)";
                hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
            }
        }
    }
    else {
        hwnd = (HWND)window_handle;
    }

    if (hwnd == nullptr) {
        return;
    }

    LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);

    if (has_opaque_pixel) {
        ex_style &= ~WS_EX_TRANSPARENT;
    }
    else {
        ex_style |= WS_EX_TRANSPARENT;
        ex_style |= WS_EX_LAYERED;
    }

    if (hide_taskbar) {
        ex_style |= WS_EX_TOOLWINDOW;
        ex_style &= ~WS_EX_APPWINDOW;
    }

    LONG result = SetWindowLong(hwnd, GWL_EXSTYLE, ex_style);

    if (result != 0) {
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    }
#endif
}

/*
 * reset_mouse_passthrough() - 重置穿透状态为正常模式
 *
 * 清除 WS_EX_TRANSPARENT 标志，恢复窗口对鼠标事件的正常接收能力。
 *
 * 与 update_mouse_passthrough 的区别：
 * - update：根据条件动态切换穿透/非穿透
 * - reset：强制清除穿透，恢复到"窗口始终可点击"的默认状态
 *
 * 使用场景：
 * - 用户禁用穿透功能时
 * - 插件销毁时
 * - 窗口切换为正常交互模式时
 *
 * 注意：会保持 hide_taskbar 的样式设置（如果之前已设置）。
 */
void MousePassthrough::reset_mouse_passthrough()
{
#ifdef _WIN32
    HWND hwnd = nullptr;

    if (window_handle == 0) {
        if (!window_title.is_empty()) {
            hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
            if (hwnd == nullptr) {
                godot::String debug_title = window_title + " (DEBUG)";
                hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
            }
        }
    }
    else {
        hwnd = (HWND)window_handle;
    }

    if (hwnd == nullptr) {
        return;
    }

    LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
    ex_style &= ~WS_EX_TRANSPARENT;
    if (hide_taskbar) {
        ex_style |= WS_EX_TOOLWINDOW;
        ex_style &= ~WS_EX_APPWINDOW;
    }
    SetWindowLong(hwnd, GWL_EXSTYLE, ex_style);

    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
#endif
}

/*
 * hide_taskbar_icon() - 隐藏主窗口在任务栏的图标
 *
 * 通过 GetWindowLongW/SetWindowLongW 修改窗口扩展样式：
 * 1. 添加 WS_EX_TOOLWINDOW：标记为工具窗口（不显示任务栏图标）
 * 2. 清除 WS_EX_APPWINDOW：移除应用程序窗口标记
 *
 * SetWindowPos 的 SWP_FRAMECHANGED 标志：
 *   通知系统窗口框架样式已更改。系统会发送 WM_NCCALCSIZE 消息
 *   给窗口以重新计算非客户区，从而使样式更改立即生效。
 *
 * SWP_NOACTIVATE 标志：
 *   更改样式时不激活窗口，避免窗口意外获得焦点。
 *
 * 延迟应用机制：
 *   如果调用时 HWND 尚未设置且无法通过标题找到窗口，
 *   仅设置 hide_taskbar 标志。后续的 update_mouse_passthrough()
 *   和 reset_mouse_passthrough() 调用会自动应用此样式。
 */
void MousePassthrough::hide_taskbar_icon()
{
    hide_taskbar = true;
#ifdef _WIN32
    HWND hwnd = nullptr;

    if (window_handle == 0) {
        if (!window_title.is_empty()) {
            hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
            if (hwnd == nullptr) {
                godot::String debug_title = window_title + " (DEBUG)";
                hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
            }
        }
    }
    else {
        hwnd = (HWND)window_handle;
    }

    if (hwnd == nullptr) {
        godot::print_line(
            godot::String::utf8("[插件:鼠标穿透] hide_taskbar_icon: 暂未找到窗口，将在每帧更新时自动重试"));
        return;
    }

    LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
    ex_style |= WS_EX_TOOLWINDOW;
    ex_style &= ~WS_EX_APPWINDOW;
    SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
    godot::print_line(godot::String::utf8("[插件:鼠标穿透] 已隐藏任务栏图标 ✅"));
#endif
}

/*
 * _bind_methods() - Godot 方法/属性绑定
 *
 * 将所有 C++ 方法注册到 Godot 的反射系统，使其可在 GDScript 中调用。
 *
 * 注册对照表：
 *   GDScript 方法名                   → C++ 方法
 *   ──────────────────────────────────────────────────
 *   set_mouse_passthrough(enabled)    → set_mouse_passthrough()
 *   get_mouse_passthrough()           → get_mouse_passthrough()
 *   set_window_handle(handle)         → set_window_handle()
 *   set_window_title(title)           → set_window_title()
 *   update_mouse_passthrough(has_px)  → update_mouse_passthrough()
 *   reset_mouse_passthrough()         → reset_mouse_passthrough()
 *   hide_taskbar_icon()               → hide_taskbar_icon()
 *
 * ADD_PROPERTY 注册：
 *   mouse_passthrough 属性（布尔类型）
 *   在 Inspector 中显示为复选框
 *   对应 set_mouse_passthrough / get_mouse_passthrough
 */
void MousePassthrough::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("set_mouse_passthrough", "enabled"), &MousePassthrough::set_mouse_passthrough);

    ClassDB::bind_method(D_METHOD("get_mouse_passthrough"), &MousePassthrough::get_mouse_passthrough);

    ClassDB::bind_method(D_METHOD("set_window_handle", "window_handle"), &MousePassthrough::set_window_handle);

    ClassDB::bind_method(D_METHOD("set_window_title", "window_title"), &MousePassthrough::set_window_title);

    ClassDB::bind_method(
        D_METHOD("update_mouse_passthrough", "has_opaque_pixel"),
        &MousePassthrough::update_mouse_passthrough);

    ClassDB::bind_method(D_METHOD("reset_mouse_passthrough"), &MousePassthrough::reset_mouse_passthrough);

    ClassDB::bind_method(D_METHOD("hide_taskbar_icon"), &MousePassthrough::hide_taskbar_icon);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "mouse_passthrough"), "set_mouse_passthrough", "get_mouse_passthrough");
}

} // namespace godot
