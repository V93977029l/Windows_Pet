/*
 * ============================================================================
 * SystemTray 类头文件 - Windows 系统托盘图标管理
 * ============================================================================
 *
 * 【项目架构角色】
 *   SystemTray 负责在 Windows 任务栏通知区域（系统托盘）创建和管理
 *   应用程序图标。它使用 Win32 API 的 Shell_NotifyIcon 系列函数，
 *   实现托盘图标的显示、隐藏、右键菜单、点击回调等功能。
 *
 * 【与 MousePassthrough 的关系】
 *   SystemTray 和 MousePassthrough 是独立的两个 GDExtension 类，
 *   分别负责不同的操作系统集成功能：
 *   - MousePassthrough: 控制窗口的鼠标穿透属性（WS_EX_TRANSPARENT）
 *   - SystemTray: 管理系统托盘图标和菜单
 *   两者在 GDScript 层可以协同使用，但 C++ 层没有直接依赖。
 *
 * 【NOTIFYICONDATA 工作原理】
 *   NOTIFYICONDATA（通知图标数据）是 Windows Shell API 的核心结构体。
 *   它封装了托盘图标的所有配置信息：
 *   - cbSize: 结构体大小（必须设置，用于版本兼容性检查）
 *   - hWnd: 接收托盘消息的窗口句柄
 *   - uID: 图标唯一标识符（支持同一窗口多个图标）
 *   - uFlags: 标志位掩码（NIF_MESSAGE|NIF_ICON|NIF_TIP 等）
 *   - uCallbackMessage: 自定义消息 ID（用于 WM_USER+1 等）
 *   - hIcon: 图标句柄
 *   - szTip[128]: 鼠标悬停提示文本（最多 127 个字符 + 空终止符）
 *
 *   Shell_NotifyIcon 的三个操作：
 *   - NIM_ADD: 添加图标到托盘
 *   - NIM_MODIFY: 修改已有图标的属性
 *   - NIM_DELETE: 从托盘移除图标
 *
 * 【消息处理架构】
 *   本类使用"隐藏消息窗口"模式处理托盘消息：
 *
 *   1. 创建一个不可见的消息窗口（tray_hwnd）
 *      - 使用 HWND_MESSAGE 作为父窗口（仅消息窗口，无 UI）
 *      - 窗口类名: "TransparentPetTrayClass"
 *
 *   2. 将消息窗口 HWND 关联到 NOTIFYICONDATA.hWnd
 *      - 当用户与托盘图标交互时，Windows 向此窗口发送消息
 *
 *   3. 静态窗口过程 tray_wnd_proc() 接收消息
 *      - 通过 s_instances 映射表找到对应的 SystemTray 实例
 *      - 调用实例的 on_tray_message() 处理具体消息
 *
 *   4. on_tray_message() 根据消息类型分发：
 *      - WM_TRAYICON + WM_LBUTTONDOWN: 左键点击 → 调用 left_click_callback
 *      - WM_TRAYICON + WM_RBUTTONUP: 右键点击 → 弹出右键菜单
 *      - TaskbarCreated 消息: 资源管理器重启后重新添加图标
 */

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
    /*
     * tooltip_text - 托盘图标悬停提示文本（默认 "桌宠"）
     *   显示在任务栏通知区域，鼠标悬停在图标上时出现
     *   最大长度 127 个字符（由 szTip[128] 限制）
     */
    String tooltip_text = "桌宠";

    /*
     * window_title - 主窗口标题
     *   用于通过 FindWindowW() 查找主窗口 HWND
     *   当用户未直接传入 HWND 时，此值作为备选查找方式
     */
    String window_title;

    /*
     * is_visible - 托盘图标当前是否可见
     *   true = 图标已通过 NIM_ADD 添加到托盘
     *   false = 图标未添加或已通过 NIM_DELETE 移除
     *   用于防止重复添加/删除操作
     */
    bool is_visible = false;

    /*
     * hide_taskbar - 是否隐藏任务栏图标
     *   true = 将主窗口设为 WS_EX_TOOLWINDOW 样式
     *   效果：窗口不在任务栏显示，但托盘图标仍然存在
     */
    bool hide_taskbar = false;

    /*
     * left_click_callback - 左键点击回调（Godot Callable）
     *   用户左键点击托盘图标时调用的 GDScript 方法
     */
    Callable left_click_callback;

    /*
     * right_click_callback - 右键菜单"退出"回调（Godot Callable）
     *   用户点击右键菜单中的"退出"项时调用
     */
    Callable right_click_callback;

#ifdef _WIN32
    /*
     * hwnd - 主窗口句柄
     *   对应 Godot 创建的主渲染窗口
     *   用于隐藏任务栏图标操作
     */
    HWND hwnd = nullptr;

    /*
     * tray_hwnd - 托盘消息窗口句柄
     *   隐藏的消息窗口，专门用于接收托盘图标相关的 Windows 消息
     *   不与任何 UI 关联（使用 HWND_MESSAGE 创建）
     */
    HWND tray_hwnd = nullptr;

    /*
     * nid - 通知图标数据结构（NOTIFYICONDATAW）
     *   存储托盘图标的所有配置信息（图标、提示文本、回调消息等）
     *   W 后缀表示使用宽字符（Unicode）版本
     */
    NOTIFYICONDATAW nid;

    /*
     * taskbar_restart_msg - TaskbarCreated 消息 ID
     *   通过 RegisterWindowMessageW("TaskbarCreated") 注册
     *   当 Windows 资源管理器（explorer.exe）重启时，系统广播此消息
     *   收到此消息后需要重新调用 NIM_ADD 恢复托盘图标
     */
    UINT taskbar_restart_msg = 0;

    /*
     * current_hicon - 当前加载的图标句柄
     *   保存 LoadImageW 返回的 HICON，用于后续的 DestroyIcon 清理
     *   防止图标资源泄漏
     */
    HICON current_hicon = nullptr;

    /*
     * s_instances - 静态实例映射表
     *   HWND → SystemTray* 的映射
     *   解决静态窗口过程需要访问实例成员的问题
     *   因为 WNDPROC 是静态函数无法直接访问 this 指针，
     *   通过此映射表可以从 HWND 反查到对应的 SystemTray 实例
     */
    static std::unordered_map<HWND, SystemTray*> s_instances;

    /*
     * tray_wnd_proc() - 静态窗口过程（消息处理回调）
     *   参数：hWnd(目标窗口), msg(消息ID), wParam, lParam(消息参数)
     *   返回值：LRESULT（消息处理结果）
     *
     *   此函数是静态的，因为 Windows 要求 WNDPROC 是静态/全局函数。
     *   通过 s_instances 映射表间接访问实例方法。
     */
    static LRESULT CALLBACK tray_wnd_proc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

    /*
     * on_tray_message() - 托盘消息处理（实例方法）
     *   由 tray_wnd_proc() 调用，处理具体的托盘交互消息
     *   处理的消息类型：
     *   - TaskbarCreated: 资源管理器重启恢复
     *   - WM_TRAYICON + 鼠标事件: 左键/右键点击
     */
    void on_tray_message(UINT msg, WPARAM wParam, LPARAM lParam);

    /*
     * show_context_menu() - 显示右键弹出菜单
     *   创建包含"设置"和"退出"两项的弹出菜单
     *   使用 TrackPopupMenu() 在鼠标位置显示
     *
     *   菜单项：
     *   - 设置（TRAY_ID_MENU_SETTINGS=1001）：点击时调用 left_click_callback
     *   - 退出（TRAY_ID_MENU_EXIT=1002）：点击时调用 right_click_callback
     */
    void show_context_menu();
#endif

protected:
    static void _bind_methods();

public:
    SystemTray();
    ~SystemTray();

    /*
     * create() - 创建托盘图标数据结构
     *   tooltip: 鼠标悬停提示文本
     *   初始化 NOTIFYICONDATA，但不立即显示图标
     *   需要随后调用 show() 才会在托盘显示
     */
    void create(const String& tooltip);

    /*
     * set_icon() - 设置托盘图标
     *   icon_path: 图标文件路径（支持 .ico 格式）
     *   使用 LoadImageW 加载图标文件
     *   如果托盘图标已显示，立即更新（NIM_MODIFY）
     */
    void set_icon(const String& icon_path);

    /*
     * set_tooltip() - 设置悬停提示文本
     *   tooltip: 新的提示文本
     *   如果托盘图标已显示，立即更新（NIM_MODIFY）
     */
    void set_tooltip(const String& tooltip);

    /*
     * show() - 在托盘显示图标
     *   完整的显示流程：
     *   1. 查找主窗口 HWND（如果未设置则通过窗口标题查找）
     *   2. 注册消息窗口类 "TransparentPetTrayClass"
     *   3. 创建隐藏消息窗口（用作托盘消息接收器）
     *   4. 调用 Shell_NotifyIconW(NIM_ADD) 添加图标
     */
    void show();

    /*
     * hide() - 隐藏托盘图标
     *   调用 Shell_NotifyIconW(NIM_DELETE) 移除图标
     *   不销毁消息窗口（可以后续再次 show()）
     */
    void hide();

    /*
     * remove() - 完全移除托盘图标
     *   相比 hide()，还会销毁消息窗口并清理实例映射
     *   通常在应用程序退出时调用
     */
    void remove();

    /*
     * set_window_title() - 设置用于查找主窗口的标题
     *   当主窗口 HWND 未直接传入时，通过此标题使用 FindWindowW 查找
     */
    void set_window_title(const String& title);

    /*
     * hide_taskbar_icon() - 隐藏主窗口在任务栏的图标
     *   通过设置 WS_EX_TOOLWINDOW 扩展样式实现
     *   WS_EX_TOOLWINDOW：窗口在任务栏不显示，Alt+Tab 列表中也隐藏
     *   清除 WS_EX_APPWINDOW：确保窗口不被识别为应用程序窗口
     *   使用 SetWindowPos 的 SWP_FRAMECHANGED 标志立即应用样式更改
     */
    void hide_taskbar_icon();

    void set_left_click_callback(const Callable& callback);
    void set_right_click_callback(const Callable& callback);

#ifdef _WIN32
    /*
     * set_hwnd() - 直接设置主窗口句柄
     *   如果已知主窗口 HWND，可通过此方法直接设置
     *   避免通过窗口标题查找的不可靠性
     */
    void set_hwnd(uint64_t hwnd);

    /*
     * get_hwnd() - 获取主窗口句柄
     *   返回类型为 uint64_t（适配 64 位指针）
     */
    uint64_t get_hwnd() const { return (uint64_t)hwnd; }
#endif

    bool get_is_visible() const { return is_visible; }
};

} // namespace godot

#endif // SYSTEM_TRAY_H
