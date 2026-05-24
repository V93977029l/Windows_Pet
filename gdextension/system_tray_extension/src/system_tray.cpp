#include "system_tray.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/print_string.hpp>
#include <string>

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>

#define WM_TRAYICON (WM_USER + 1)
#define TRAY_ID_MENU_SETTINGS 1001
#define TRAY_ID_MENU_EXIT     1002

static std::wstring godot_string_to_wide(const godot::String& str) {
    const char16_t* utf16_data = str.utf16().get_data();
    std::wstring result;
    while (*utf16_data) {
        result += (wchar_t)*utf16_data;
        utf16_data++;
    }
    return result;
}
#endif

namespace godot {

#ifdef _WIN32
std::unordered_map<HWND, SystemTray*> SystemTray::s_instances;
#endif

SystemTray::SystemTray() {
    godot::print_line(godot::String::utf8("[系统托盘] 构造函数"));
}

SystemTray::~SystemTray() {
    godot::print_line(godot::String::utf8("[系统托盘] 析构函数"));
    remove();
}

void SystemTray::_bind_methods() {
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

void SystemTray::create(const String& tooltip) {
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

void SystemTray::set_icon(const String& icon_path) {
#ifdef _WIN32
    if (icon_path.is_empty()) {
        godot::print_line(godot::String::utf8("[系统托盘] 图标路径为空"));
        return;
    }

    std::wstring wide_path = godot_string_to_wide(icon_path);
    HICON hIcon = (HICON)LoadImageW(nullptr, wide_path.c_str(), IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE | LR_SHARED);

    if (hIcon) {
        if (current_hicon) DestroyIcon(current_hicon);
        current_hicon = hIcon;
        nid.hIcon = hIcon;
        nid.uFlags |= NIF_ICON;
        godot::print_line(godot::String::utf8("[系统托盘] 加载图标成功: ") + icon_path);

        if (is_visible) {
            Shell_NotifyIconW(NIM_MODIFY, &nid);
        }
    } else {
        godot::print_line(godot::String::utf8("[系统托盘] 加载图标失败: ") + icon_path);
    }
#endif
}

void SystemTray::set_tooltip(const String& tooltip) {
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

void SystemTray::show() {
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
            godot::print_line(godot::String::utf8("[系统托盘] 错误: 注册窗口类失败, err=") + godot::String::num_int64(err));
        }
    }

    tray_hwnd = CreateWindowExW(
        0,
        L"TransparentPetTrayClass",
        L"TransparentPetTray",
        0,
        0, 0, 0, 0,
        HWND_MESSAGE,
        nullptr,
        GetModuleHandleW(nullptr),
        this
    );

    if (tray_hwnd == nullptr) {
        godot::print_line(godot::String::utf8("[系统托盘] 错误: 创建消息窗口失败"));
        return;
    }

    s_instances[tray_hwnd] = this;
    godot::print_line(godot::String::utf8("[系统托盘] 消息窗口已创建, HWND=") + godot::String::num_uint64((uint64_t)tray_hwnd) + godot::String::utf8(", 已注册到实例表"));

    nid.hWnd = tray_hwnd;

    BOOL result = Shell_NotifyIconW(NIM_ADD, &nid);
    if (result) {
        is_visible = true;
        godot::print_line(godot::String::utf8("[系统托盘] 显示托盘图标 ✅"));
    } else {
        godot::print_line(godot::String::utf8("[系统托盘] 显示托盘图标失败 ❌"));
    }
#endif
}

void SystemTray::hide() {
#ifdef _WIN32
    if (!is_visible) return;

    BOOL result = Shell_NotifyIconW(NIM_DELETE, &nid);
    if (result) {
        is_visible = false;
        godot::print_line(godot::String::utf8("[系统托盘] 隐藏托盘图标"));
    }
#endif
}

void SystemTray::remove() {
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

void SystemTray::set_left_click_callback(const Callable& callback) {
    left_click_callback = callback;
    godot::print_line(godot::String::utf8("[系统托盘] 设置左键回调"));
}

void SystemTray::set_right_click_callback(const Callable& callback) {
    right_click_callback = callback;
    godot::print_line(godot::String::utf8("[系统托盘] 设置右键回调"));
}

void SystemTray::set_window_title(const String& title) {
    window_title = title;
    godot::print_line(godot::String::utf8("[系统托盘] 设置窗口标题: ") + title);
}

void SystemTray::hide_taskbar_icon() {
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
void SystemTray::set_hwnd(uint64_t p_hwnd) {
    hwnd = (HWND)p_hwnd;
    godot::print_line(godot::String::utf8("[系统托盘] 设置主窗口 HWND: ") + godot::String::num_uint64(p_hwnd));
}

LRESULT CALLBACK SystemTray::tray_wnd_proc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
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

void SystemTray::on_tray_message(UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == taskbar_restart_msg && is_visible) {
        godot::print_line(godot::String::utf8("[系统托盘] TaskbarCreated: 重新添加图标"));
        Shell_NotifyIconW(NIM_ADD, &nid);
        if (hide_taskbar && hwnd) {
            LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
            ex_style |= WS_EX_TOOLWINDOW;
            ex_style &= ~WS_EX_APPWINDOW;
            SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style);
            SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
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

void SystemTray::show_context_menu() {
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
