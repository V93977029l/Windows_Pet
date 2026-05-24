#ifndef SYSTEM_TRAY_H
#define SYSTEM_TRAY_H

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/callable.hpp>

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#include <unordered_map>
#endif

namespace godot {

class SystemTray : public Object {
    GDCLASS(SystemTray, Object);

private:
    String tooltip_text = "桌宠";
    String window_title;
    bool is_visible = false;
    bool hide_taskbar = false;
    Callable left_click_callback;
    Callable right_click_callback;

#ifdef _WIN32
    HWND hwnd = nullptr;
    HWND tray_hwnd = nullptr;
    NOTIFYICONDATAW nid;
    UINT taskbar_restart_msg = 0;
    HICON current_hicon = nullptr;

    static std::unordered_map<HWND, SystemTray*> s_instances;
    static LRESULT CALLBACK tray_wnd_proc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
    void on_tray_message(UINT msg, WPARAM wParam, LPARAM lParam);
    void show_context_menu();
#endif

protected:
    static void _bind_methods();

public:
    SystemTray();
    ~SystemTray();

    void create(const String& tooltip);
    void set_icon(const String& icon_path);
    void set_tooltip(const String& tooltip);
    void show();
    void hide();
    void remove();

    void set_window_title(const String& title);
    void hide_taskbar_icon();
    void set_left_click_callback(const Callable& callback);
    void set_right_click_callback(const Callable& callback);

#ifdef _WIN32
    void set_hwnd(uint64_t hwnd);
    uint64_t get_hwnd() const { return (uint64_t)hwnd; }
#endif

    bool get_is_visible() const { return is_visible; }
};

} // namespace godot

#endif // SYSTEM_TRAY_H
