/*
 * ============================================================================
 * SystemTray 类实现 - Windows 系统托盘图标管理
 * ============================================================================
 *
 * 【实现概述】
 *   本文件实现了基于 Win32 Shell API 的系统托盘图标管理功能。
 *   核心机制是"隐藏消息窗口"模式：创建一个仅用于接收消息的不可见窗口，
 *   通过 Windows 的消息循环机制处理托盘交互事件。
 *
 * 【Shell_NotifyIcon 函数说明】
 *   Shell_NotifyIcon 是 Windows Shell API 的核心函数，用于管理通知区域图标。
 *   它的三个操作码：
 *   - NIM_ADD: 向任务栏通知区域添加图标
 *   - NIM_MODIFY: 修改已有图标的属性（图标、提示文本等）
 *   - NIM_DELETE: 从通知区域移除图标
 *
 *   所有操作都通过 NOTIFYICONDATA 结构体传递参数。
 *
 * 【FindWindowW 函数说明】
 *   FindWindowW 通过窗口类名和/或窗口标题查找顶层窗口句柄。
 *   参数：
 *   - lpClassName: 窗口类名（nullptr 表示匹配任意类名）
 *   - lpWindowName: 窗口标题（nullptr 表示匹配任意标题）
 *   返回值：找到的窗口 HWND，未找到则返回 nullptr
 *
 *   本类使用窗口标题来查找 Godot 主窗口的 HWND。
 *   由于 Godot 在调试模式下会在标题后添加 " (DEBUG)"，因此需要额外
 *   尝试带 "(DEBUG)" 后缀的标题查找。
 *
 * 【TaskbarCreated 消息恢复机制】
 *   当 Windows 资源管理器（explorer.exe）崩溃或重启时，任务栏及其
 *   通知区域会被重建。此时所有通过 Shell_NotifyIcon 添加的图标都会
 *   消失，且不会自动恢复。
 *
 *   恢复机制：
 *   1. 在 show() 时通过 RegisterWindowMessageW("TaskbarCreated") 注册
 *      全局消息 ID
 *   2. 当 explorer.exe 重启时，系统广播 TaskbarCreated 消息到所有顶层窗口
 *   3. 消息窗口收到此消息后，重新调用 NIM_ADD 恢复图标
 *   4. 同时检查 hide_taskbar 状态，如果需要则重新隐藏任务栏图标
 */

#include "system_tray.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/godot.hpp>
#include <string>

#ifdef _WIN32
#include <shellapi.h>
#include <windows.h>

/*
 * WM_TRAYICON - 自定义托盘消息 ID
 *   WM_USER + 1 = 0x0401
 *   WM_USER (0x0400) 是 Windows 为用户定义消息保留的起始值
 *   选择 +1 作为第一个自定义消息，避免与 WM_USER 本身冲突
 */
#define WM_TRAYICON (WM_USER + 1)

/*
 * TRAY_ID_MENU_SETTINGS - 右键菜单"设置"项的 ID
 *   值 1001，用于在 WM_COMMAND 消息中识别菜单项点击
 */
#define TRAY_ID_MENU_SETTINGS 1001

/*
 * TRAY_ID_MENU_EXIT - 右键菜单"退出"项的 ID
 *   值 1002，与 SETTINGS 相邻便于管理
 */
#define TRAY_ID_MENU_EXIT 1002

/*
 * godot_string_to_wide() - Godot String 转 Windows 宽字符串
 *   辅助函数：将 Godot 的 UTF-16 字符串转换为 std::wstring
 *   用于传递给 Windows API 的 W 后缀函数（如 wcsncpy_s）
 *
 *   流程：
 *   1. 获取 Godot String 的 UTF-16 数据指针
 *   2. 逐字符复制到 std::wstring
 *   3. 遇到空字符 (\0) 停止
 */
static std::wstring godot_string_to_wide(const godot::String& str)
{
    const char16_t* utf16_data = str.utf16().get_data();
    std::wstring result;
    while (*utf16_data) {
        result += (wchar_t)*utf16_data;
        utf16_data++;
    }
    return result;
}
#endif

namespace godot
{

#ifdef _WIN32
// 静态实例映射表定义 - 用于从 HWND 查找 SystemTray 实例
std::unordered_map<HWND, SystemTray*> SystemTray::s_instances;
#endif

/*
 * 构造函数
 *   仅输出日志，实际初始化在 create() 和 show() 中进行
 */
SystemTray::SystemTray()
{
    godot::print_line(godot::String::utf8("[系统托盘] 构造函数"));
}

/*
 * 析构函数
 *   自动调用 remove() 清理托盘图标和消息窗口
 *   确保即使 GDScript 忘记调用 remove()，资源也能正确释放
 */
SystemTray::~SystemTray()
{
    godot::print_line(godot::String::utf8("[系统托盘] 析构函数"));
    remove();
}

/*
 * _bind_methods() - Godot 方法绑定
 *   将所有公开方法暴露给 GDScript
 */
void SystemTray::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("create", "tooltip"), &SystemTray::create);
    ClassDB::bind_method(D_METHOD("set_icon", "icon_path"), &SystemTray::set_icon);
    ClassDB::bind_method(D_METHOD("set_tooltip", "tooltip"), &SystemTray::set_tooltip);
    ClassDB::bind_method(D_METHOD("set_window_title", "title"), &SystemTray::set_window_title);
    ClassDB::bind_method(D_METHOD("hide_taskbar_icon"), &SystemTray::hide_taskbar_icon);
    ClassDB::bind_method(D_METHOD("show"), &SystemTray::show);
    ClassDB::bind_method(D_METHOD("hide"), &SystemTray::hide);
    ClassDB::bind_method(D_METHOD("remove"), &SystemTray::remove);
    ClassDB::bind_method(D_METHOD("set_left_click_callback", "callback"), &SystemTray::set_left_click_callback);
    ClassDB::bind_method(D_METHOD("set_right_click_callback", "callback"), &SystemTray::set_right_click_callback);
    ClassDB::bind_method(D_METHOD("get_is_visible"), &SystemTray::get_is_visible);
    ClassDB::bind_method(D_METHOD("set_hwnd", "hwnd"), &SystemTray::set_hwnd);
}

/*
 * create() - 初始化托盘图标数据结构
 *
 * 此方法预填充 NOTIFYICONDATA 结构体，但不立即显示图标。
 * 需要随后调用 show() 才会通过 NIM_ADD 在托盘显示。
 *
 * NOTIFYICONDATA 关键字段设置：
 * - cbSize: sizeof(NOTIFYICONDATAW) - 必须设置，用于 API 版本兼容
 * - uID: 1 - 图标标识符（同一窗口可以有多个图标）
 * - uFlags: NIF_MESSAGE|NIF_ICON|NIF_TIP
 *     NIF_MESSAGE: 使用 uCallbackMessage 接收消息
 *     NIF_ICON: 使用 hIcon 显示图标
 *     NIF_TIP: 使用 szTip 显示提示文本
 * - hIcon: LoadIconW(nullptr, IDI_APPLICATION) - 加载系统默认应用图标作为初始图标
 * - uCallbackMessage: WM_TRAYICON - 托盘交互消息 ID
 *
 * TaskbarCreated 消息注册：
 * RegisterWindowMessageW("TaskbarCreated") 注册一个全局唯一的消息 ID
 * 用于接收系统资源管理器重启的通知
 */
void SystemTray::create(const String& tooltip)
{
#ifdef _WIN32
    tooltip_text = tooltip;

    memset(&nid, 0, sizeof(nid));
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.uID = 1;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    nid.hIcon = LoadIconW(nullptr, (LPCWSTR)IDI_APPLICATION);
    nid.uCallbackMessage = WM_TRAYICON;

    if (!tooltip.is_empty()) {
        std::wstring wtip = godot_string_to_wide(tooltip);
        wcsncpy_s(nid.szTip, wtip.c_str(), 127);
        nid.szTip[127] = L'\0';
    }

    taskbar_restart_msg = RegisterWindowMessageW(L"TaskbarCreated");

    godot::print_line(godot::String::utf8("[系统托盘] 创建托盘图标数据结构"));
#endif
}

/*
 * set_icon() - 加载并设置托盘图标
 *
 * LoadImageW 参数说明：
 * - nullptr: 不使用实例句柄（直接从文件加载）
 * - wide_path.c_str(): 图标文件路径
 * - IMAGE_ICON: 指定加载图标类型
 * - 0, 0: 使用原始尺寸
 * - LR_LOADFROMFILE: 从文件加载（而非资源）
 * - LR_DEFAULTSIZE: 如果尺寸为 0，使用系统默认图标尺寸
 * - LR_SHARED: 共享图标句柄（多次加载同一图标时复用）
 *
 * 图标更新流程：
 * 1. 如果之前有图标，先调用 DestroyIcon 释放
 * 2. 加载新图标
 * 3. 更新 nid.hIcon 和 nid.uFlags
 * 4. 如果已显示，立即通过 NIM_MODIFY 更新
 */
void SystemTray::set_icon(const String& icon_path)
{
#ifdef _WIN32
    if (icon_path.is_empty()) {
        godot::print_line(godot::String::utf8("[系统托盘] 图标路径为空"));
        return;
    }

    std::wstring wide_path = godot_string_to_wide(icon_path);
    HICON hIcon =
        (HICON)LoadImageW(nullptr, wide_path.c_str(), IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE | LR_SHARED);

    if (hIcon) {
        if (current_hicon) {
            DestroyIcon(current_hicon);
        }
        current_hicon = hIcon;
        nid.hIcon = hIcon;
        nid.uFlags |= NIF_ICON;
        godot::print_line(godot::String::utf8("[系统托盘] 加载图标成功: ") + icon_path);

        if (is_visible) {
            Shell_NotifyIconW(NIM_MODIFY, &nid);
        }
    }
    else {
        godot::print_line(godot::String::utf8("[系统托盘] 加载图标失败: ") + icon_path);
    }
#endif
}

/*
 * set_tooltip() - 设置托盘图标悬停提示文本
 *
 * wcsncpy_s 参数说明：
 * - nid.szTip: 目标缓冲区
 * - wtip.c_str(): 源字符串
 * - 127: 最多复制 127 个字符（szTip[128] 的最后一位留给 \0）
 *
 * szTip 的长度限制为 128 个宽字符，这是 Windows Shell API 的硬性限制。
 */
void SystemTray::set_tooltip(const String& tooltip)
{
#ifdef _WIN32
    tooltip_text = tooltip;
    std::wstring wtip = godot_string_to_wide(tooltip);
    wcsncpy_s(nid.szTip, wtip.c_str(), 127);
    nid.szTip[127] = L'\0';
    nid.uFlags |= NIF_TIP;

    if (is_visible) {
        Shell_NotifyIconW(NIM_MODIFY, &nid);
    }
    godot::print_line(godot::String::utf8("[系统托盘] 设置提示文本: ") + tooltip);
#endif
}

/*
 * show() - 在系统托盘显示图标
 *
 * 完整流程（6个步骤）：
 *
 * 步骤1：防重复检查
 *   如果 is_visible 已为 true，直接返回
 *
 * 步骤2：获取主窗口 HWND
 *   优先使用直接设置的 hwnd，如果为空则通过窗口标题查找
 *   FindWindowW 查找策略：
 *   - 先查找原始标题
 *   - 再查找带 "(DEBUG)" 后缀的标题（Godot 调试模式）
 *   如果两者都找不到，返回错误
 *
 * 步骤3：注册消息窗口类
 *   WNDCLASSEXW 配置：
 *   - lpfnWndProc: 指向静态窗口过程 tray_wnd_proc
 *   - hInstance: 当前模块句柄
 *   - lpszClassName: "TransparentPetTrayClass"
 *   RegisterClassExW 可能失败（类已注册），忽略 ERROR_CLASS_ALREADY_EXISTS
 *
 * 步骤4：创建隐藏消息窗口
 *   CreateWindowExW 参数：
 *   - 0: 无扩展样式
 *   - "TransparentPetTrayClass": 使用刚注册的窗口类
 *   - "TransparentPetTray": 窗口标题（仅用于识别）
 *   - 0: 无窗口样式
 *   - 0,0,0,0: 位置和尺寸（隐藏窗口不需要）
 *   - HWND_MESSAGE: 仅消息窗口（不创建 UI 元素）
 *   - nullptr: 无菜单
 *   - GetModuleHandleW(nullptr): 当前模块句柄
 *   - this: 传入 this 指针作为 CREATESTRUCT 的 lpCreateParams
 *
 * 步骤5：注册实例映射
 *   将 tray_hwnd → this 存入 s_instances 映射表
 *   使静态窗口过程能访问此实例的成员方法
 *
 * 步骤6：添加托盘图标
 *   Shell_NotifyIconW(NIM_ADD, &nid)
 *   将配置好的 NOTIFYICONDATA 提交给系统
 *   成功后设置 is_visible = true
 */
void SystemTray::show()
{
#ifdef _WIN32
    if (is_visible) {
        godot::print_line(godot::String::utf8("[系统托盘] 托盘图标已显示"));
        return;
    }

    if (hwnd == nullptr) {
        if (window_title.is_empty()) {
            godot::print_line(godot::String::utf8("[系统托盘] 错误: HWND 未设置且无窗口标题"));
            return;
        }
        hwnd = FindWindowW(nullptr, (LPCWSTR)window_title.utf16().get_data());
        if (hwnd == nullptr) {
            godot::String debug_title = window_title + " (DEBUG)";
            hwnd = FindWindowW(nullptr, (LPCWSTR)debug_title.utf16().get_data());
        }
        if (hwnd == nullptr) {
            godot::print_line(godot::String::utf8("[系统托盘] 错误: 无法通过标题找到窗口: ") + window_title);
            return;
        }
        godot::print_line(godot::String::utf8("[系统托盘] 通过 FindWindowW 找到主窗口 HWND"));
    }

    WNDCLASSEXW wc = { 0 };
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = &SystemTray::tray_wnd_proc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = L"TransparentPetTrayClass";
    ATOM atom = RegisterClassExW(&wc);
    if (atom == 0) {
        DWORD err = GetLastError();
        if (err != ERROR_CLASS_ALREADY_EXISTS) {
            godot::print_line(
                godot::String::utf8("[系统托盘] 错误: 注册窗口类失败, err=") + godot::String::num_int64(err));
        }
    }

    tray_hwnd = CreateWindowExW(
        0,
        L"TransparentPetTrayClass",
        L"TransparentPetTray",
        0,
        0,
        0,
        0,
        0,
        HWND_MESSAGE,
        nullptr,
        GetModuleHandleW(nullptr),
        this);

    if (tray_hwnd == nullptr) {
        godot::print_line(godot::String::utf8("[系统托盘] 错误: 创建消息窗口失败"));
        return;
    }

    s_instances[tray_hwnd] = this;
    godot::print_line(
        godot::String::utf8("[系统托盘] 消息窗口已创建, HWND=") + godot::String::num_uint64((uint64_t)tray_hwnd) +
        godot::String::utf8(", 已注册到实例表"));

    nid.hWnd = tray_hwnd;

    BOOL result = Shell_NotifyIconW(NIM_ADD, &nid);
    if (result) {
        is_visible = true;
        godot::print_line(godot::String::utf8("[系统托盘] 显示托盘图标 ✅"));
    }
    else {
        godot::print_line(godot::String::utf8("[系统托盘] 显示托盘图标失败 ❌"));
    }
#endif
}

/*
 * hide() - 从托盘隐藏图标
 *   调用 Shell_NotifyIconW(NIM_DELETE) 移除图标
 *   不销毁消息窗口，之后可以再次 show() 恢复
 */
void SystemTray::hide()
{
#ifdef _WIN32
    if (!is_visible) {
        return;
    }

    BOOL result = Shell_NotifyIconW(NIM_DELETE, &nid);
    if (result) {
        is_visible = false;
        godot::print_line(godot::String::utf8("[系统托盘] 隐藏托盘图标"));
    }
#endif
}

/*
 * remove() - 完全移除托盘图标和相关资源
 *
 * 与 hide() 的区别：
 * - hide() 只移除图标，保留消息窗口（可恢复）
 * - remove() 移除图标并销毁消息窗口（不可恢复，需要重建）
 *
 * 清理步骤：
 * 1. 如果可见，调用 NIM_DELETE 移除图标
 * 2. 从 s_instances 映射表中移除条目
 * 3. 调用 DestroyWindow 销毁消息窗口
 */
void SystemTray::remove()
{
#ifdef _WIN32
    if (is_visible) {
        Shell_NotifyIconW(NIM_DELETE, &nid);
        is_visible = false;
        godot::print_line(godot::String::utf8("[系统托盘] 移除托盘图标"));
    }
    if (tray_hwnd) {
        s_instances.erase(tray_hwnd);
        DestroyWindow(tray_hwnd);
        tray_hwnd = nullptr;
        godot::print_line(godot::String::utf8("[系统托盘] 消息窗口已销毁"));
    }
#endif
}

void SystemTray::set_left_click_callback(const Callable& callback)
{
    left_click_callback = callback;
    godot::print_line(godot::String::utf8("[系统托盘] 设置左键回调"));
}

void SystemTray::set_right_click_callback(const Callable& callback)
{
    right_click_callback = callback;
    godot::print_line(godot::String::utf8("[系统托盘] 设置右键回调"));
}

void SystemTray::set_window_title(const String& title)
{
    window_title = title;
    godot::print_line(godot::String::utf8("[系统托盘] 设置窗口标题: ") + title);
}

/*
 * hide_taskbar_icon() - 隐藏主窗口在任务栏的图标
 *
 * Windows 扩展窗口样式说明：
 * - WS_EX_TOOLWINDOW: 将窗口标记为工具窗口
 *     效果：不显示在任务栏、不在 Alt+Tab 列表中
 * - WS_EX_APPWINDOW: 强制窗口在任务栏显示
 *     需要清除此标志才能配合 WS_EX_TOOLWINDOW 生效
 *
 * SetWindowPos 参数：
 * - SWP_NOMOVE: 保持窗口位置不变
 * - SWP_NOSIZE: 保持窗口尺寸不变
 * - SWP_NOZORDER: 保持 Z 顺序不变
 * - SWP_FRAMECHANGED: 通知系统窗口框架已更改（强制重绘非客户区）
 * - SWP_NOACTIVATE: 不激活窗口
 *
 * 组合使用这些标志的效果：仅更新窗口样式而不改变其外观状态。
 */
void SystemTray::hide_taskbar_icon()
{
    hide_taskbar = true;
#ifdef _WIN32
    if (hwnd == nullptr) {
        godot::print_line(godot::String::utf8("[系统托盘] hide_taskbar_icon: HWND 未设置，将在 show() 之后自动应用"));
        return;
    }

    LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
    ex_style |= WS_EX_TOOLWINDOW;
    ex_style &= ~WS_EX_APPWINDOW;
    SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
    godot::print_line(godot::String::utf8("[系统托盘] 已隐藏任务栏图标 ✅"));
#endif
}

#ifdef _WIN32
void SystemTray::set_hwnd(uint64_t p_hwnd)
{
    hwnd = (HWND)p_hwnd;
    godot::print_line(godot::String::utf8("[系统托盘] 设置主窗口 HWND: ") + godot::String::num_uint64(p_hwnd));
}

/*
 * tray_wnd_proc() - 静态窗口过程（消息处理入口）
 *
 * 这是一个静态函数，Windows 系统在托盘事件发生时调用它。
 * 它不能直接访问 SystemTray 的实例成员，必须通过 s_instances 映射表
 * 从 HWND 反查到对应的实例指针。
 *
 * 消息处理流程：
 * 1. 查找实例：从 s_instances 通过 hWnd 获取 SystemTray* 指针
 * 2. 如果找不到实例：调用 DefWindowProcW 使用默认消息处理
 * 3. 调用 self->on_tray_message() 处理托盘相关消息
 * 4. 额外处理 WM_COMMAND 消息（菜单项点击）：
 *    - TRAY_ID_MENU_SETTINGS (1001)：调用 left_click_callback
 *    - TRAY_ID_MENU_EXIT (1002)：调用 right_click_callback
 * 5. 未处理的消息传递给 DefWindowProcW
 *
 * 注意：WM_COMMAND 中的 wParam 低位字（LOWORD）是菜单项 ID。
 */
LRESULT CALLBACK SystemTray::tray_wnd_proc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    auto it = s_instances.find(hWnd);
    SystemTray* self = (it != s_instances.end()) ? it->second : nullptr;

    if (!self) {
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }

    self->on_tray_message(msg, wParam, lParam);

    if (msg == WM_COMMAND) {
        WORD id = LOWORD(wParam);
        if (id == TRAY_ID_MENU_SETTINGS) {
            godot::String s("[系统托盘] 菜单: 设置");
            godot::print_line(s);
            if (self->left_click_callback.is_valid()) {
                self->left_click_callback.call();
            }
            return 0;
        }
        if (id == TRAY_ID_MENU_EXIT) {
            godot::String s("[系统托盘] 菜单: 退出");
            godot::print_line(s);
            if (self->right_click_callback.is_valid()) {
                self->right_click_callback.call();
            }
            return 0;
        }
    }

    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

/*
 * on_tray_message() - 托盘消息处理
 *
 * 处理两种关键消息：
 *
 * 1. TaskbarCreated 消息（资源管理器重启恢复）
 *    当 Windows 资源管理器重启时，系统广播此消息。
 *    收到后需要：
 *    - 重新调用 NIM_ADD 恢复托盘图标
 *    - 如果 hide_taskbar 为 true，重新设置窗口样式
 *    否则图标会永久消失，直到应用程序重启。
 *
 * 2. WM_TRAYICON 消息（用户交互）
 *    条件：msg == WM_TRAYICON && wParam == 1（图标 ID 为 1）
 *    根据 lParam（事件类型）分发：
 *    - WM_RBUTTONUP / WM_RBUTTONDOWN: 右键点击 → 显示右键菜单
 *    - WM_LBUTTONDOWN: 左键点击 → 调用 left_click_callback
 *
 * WM_TRAYICON 机制：
 *   当用户在托盘图标上进行操作时（点击、悬停等），Windows 向
 *   NOTIFYICONDATA 中指定的 hWnd 发送 uCallbackMessage 消息。
 *   wParam 是图标的 uID，lParam 是具体的事件类型。
 */
void SystemTray::on_tray_message(UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (msg == taskbar_restart_msg && is_visible) {
        godot::print_line(godot::String::utf8("[系统托盘] TaskbarCreated: 重新添加图标"));
        Shell_NotifyIconW(NIM_ADD, &nid);
        if (hide_taskbar && hwnd) {
            LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
            ex_style |= WS_EX_TOOLWINDOW;
            ex_style &= ~WS_EX_APPWINDOW;
            SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style);
            SetWindowPos(
                hwnd,
                nullptr,
                0,
                0,
                0,
                0,
                SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
            godot::print_line(godot::String::utf8("[系统托盘] TaskbarCreated: 重新隐藏任务栏图标"));
        }
        return;
    }

    if (msg == WM_TRAYICON && wParam == 1) {
        UINT event = (UINT)lParam;

        switch (event) {
        case WM_RBUTTONUP:
        case WM_RBUTTONDOWN:
            godot::print_line(godot::String::utf8("[系统托盘] 右键点击 → 显示菜单"));
            show_context_menu();
            break;
        case WM_LBUTTONDOWN:
            godot::print_line(godot::String::utf8("[系统托盘] 左键点击"));
            if (left_click_callback.is_valid()) {
                left_click_callback.call();
            }
            break;
        default:
            break;
        }
    }
}

/*
 * show_context_menu() - 创建并显示右键弹出菜单
 *
 * Win32 菜单创建流程：
 *
 * 1. CreatePopupMenu()
 *    创建一个空的弹出菜单
 *
 * 2. AppendMenuW()
 *    向菜单添加菜单项
 *    - hMenu: 菜单句柄
 *    - MF_STRING: 菜单项类型为文本字符串
 *    - TRAY_ID_MENU_SETTINGS / TRAY_ID_MENU_EXIT: 菜单项 ID
 *    - L"设置" / L"退出": 菜单项显示的文本
 *
 * 3. GetCursorPos(&pt)
 *    获取当前鼠标光标屏幕坐标
 *    菜单将在鼠标位置弹出
 *
 * 4. SetForegroundWindow(tray_hwnd)
 *    临时将消息窗口设为前台窗口
 *    这是 TrackPopupMenu 正常工作的必要条件（否则点击菜单外区域不会消失）
 *
 * 5. TrackPopupMenu()
 *    在指定位置显示弹出菜单并跟踪用户选择
 *    - TPM_BOTTOMALIGN | TPM_LEFTALIGN: 菜单对齐方式
 *    - pt.x, pt.y: 弹出位置
 *    - 0: 保留参数（未使用）
 *    - tray_hwnd: 接收菜单消息的窗口
 *
 * 6. PostMessageW(tray_hwnd, WM_NULL, 0, 0)
 *    向消息窗口发送空消息（解除菜单消息循环阻塞）
 *    这是 Win32 菜单处理的标准做法
 *
 * 7. DestroyMenu(hMenu)
 *    销毁菜单及其资源
 *    注意：必须在菜单关闭后才能销毁
 */
void SystemTray::show_context_menu()
{
    HMENU hMenu = CreatePopupMenu();
    if (!hMenu) {
        godot::print_line(godot::String::utf8("[系统托盘] CreatePopupMenu 失败"));
        return;
    }

    AppendMenuW(hMenu, MF_STRING, TRAY_ID_MENU_SETTINGS, L"设置");
    AppendMenuW(hMenu, MF_STRING, TRAY_ID_MENU_EXIT, L"退出");

    POINT pt;
    GetCursorPos(&pt);

    SetForegroundWindow(tray_hwnd);

    TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, tray_hwnd, nullptr);

    PostMessageW(tray_hwnd, WM_NULL, 0, 0);

    DestroyMenu(hMenu);
}
#endif

} // namespace godot
