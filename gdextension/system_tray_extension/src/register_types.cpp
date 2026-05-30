/*
 * ============================================================================
 * SystemTray 扩展注册 - GDExtension 初始化/清理入口
 * ============================================================================
 *
 * 【文件角色】
 *   本文件是 SystemTray GDExtension 的入口点。与 LiquidGlass 的
 *   register_types.cpp 结构相同，负责 GDExtension 的生命周期管理。
 *
 * 【注册流程】
 *   1. Godot 引擎加载 system_tray.dll
 *   2. 调用 system_tray_library_init()（C 入口函数）
 *   3. 内部创建 GDExtensionBinding::InitObject，注册回调
 *   4. 当引擎到达 MODULE_INITIALIZATION_LEVEL_SCENE 时
 *   5. 调用 initialize_system_tray_module()
 *   6. ClassDB::register_class<SystemTray>() 将类注册到类型系统
 *
 * 【清理流程】
 *   引擎退出时，SCENE 级别的 uninitialize_system_tray_module() 被调用。
 *   当前不需要手动清理（SystemTray 的析构函数自动处理资源释放）。
 */

#include "system_tray.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

/*
 * initialize_system_tray_module() - 扩展初始化回调
 *   p_level: 当前初始化级别
 *
 *   仅在 MODULE_INITIALIZATION_LEVEL_SCENE 时注册 SystemTray 类。
 *   选择 SCENE 级别的原因：SystemTray 是一个 Object 类，需要在
 *   场景系统就绪后注册，以确保 GDScript 绑定正常工作。
 */
void initialize_system_tray_module(ModuleInitializationLevel p_level) {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<SystemTray>();
    }
}

/*
 * uninitialize_system_tray_module() - 扩展清理回调
 *
 *   清理工作由 SystemTray 的析构函数自动处理：
 *   - 移除托盘图标（NIM_DELETE）
 *   - 销毁消息窗口
 *   - 清理实例映射表
 *   因此此回调不需要执行额外操作。
 */
void uninitialize_system_tray_module(ModuleInitializationLevel p_level) {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        // Cleanup handled in destructor
    }
}

/*
 * system_tray_library_init() - GDExtension C 入口函数
 *
 *   此函数名必须与 .gdextension 配置文件中的 "entry_symbol" 字段匹配。
 *   GDExtension 规范要求函数签名为：
 *   GDExtensionBool (GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr, GDExtensionInitialization*)
 *
 *   参数和流程与 liquid_glass_extension_init() 完全相同。
 */
extern "C" {
    GDExtensionBool GDE_EXPORT system_tray_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_system_tray_module);
        init_obj.register_terminator(uninitialize_system_tray_module);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}
