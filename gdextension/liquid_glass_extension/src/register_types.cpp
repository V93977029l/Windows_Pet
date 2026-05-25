/*
 * ============================================================================
 * LiquidGlass 扩展注册 - GDExtension 初始化/清理入口
 * ============================================================================
 *
 * 【文件角色】
 *   本文件是 LiquidGlass GDExtension 的入口点。它负责：
 *   1. 在 Godot 引擎初始化时注册 LiquidGlass 类
 *   2. 在 Godot 引擎清理时执行必要的反注册
 *   3. 作为 C 接口导出的入口函数（extern "C"）
 *
 * 【GDExtension 生命周期】
 *   Godot 引擎在启动时按顺序经历以下初始化级别
 *   （ModuleInitializationLevel）：
 *
 *   MODULE_INITIALIZATION_LEVEL_CORE       - 核心系统初始化（最低级）
 *   MODULE_INITIALIZATION_LEVEL_SERVERS    - 服务器系统初始化
 *   MODULE_INITIALIZATION_LEVEL_SCENE      - 场景系统初始化 ⬅ 我们使用的级别
 *   MODULE_INITIALIZATION_LEVEL_EDITOR     - 编辑器初始化（仅编辑器模式）
 *
 *   选择 SCENE 级别的理由：
 *   LiquidGlass 是一个 Resource 类，Resource 需要在场景系统就绪后才能
 *   安全地注册。如果在 CORE 级别注册，场景系统尚未就绪，可能导致
 *   Resource 类注册失败或行为异常。
 *
 * 【extern "C" 说明】
 *   入口函数必须使用 extern "C" 链接，因为 Godot 引擎通过 dlopen/LoadLibrary
 *   等动态库加载机制加载 .dll/.so 文件，然后通过函数指针调用入口函数。
 *   C++ 的名称修饰（name mangling）会导致函数名不匹配，extern "C" 禁用
 *   名称修饰。
 *
 * 【GDExtensionInterfaceGetProcAddress 说明】
 *   Godot 引擎通过此函数指针向扩展提供内部 API 的访问接口。
 *   扩展可以使用它来获取其他 Godot 内部函数的地址。
 *   在 GDExtensionBinding::InitObject 中自动处理。
 */

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "liquid_glass.h"

using namespace godot;

/*
 * initialize_liquid_glass_extension() - 扩展初始化回调
 *   p_level: Godot 引擎当前的初始化级别
 *
 *   流程：
 *   1. 检查初始化级别是否为 SCENE 级别
 *      - 如果不是，直接返回（等待正确的初始化时机）
 *   2. 在 SCENE 级别，调用 ClassDB::register_class<LiquidGlass>()
 *      将 LiquidGlass 类注册到 Godot 的类型系统
 *      - 此后 LiquidGlass 可以在 GDScript 中被实例化
 *      - 可以在编辑器的 Inspector 中作为 Resource 编辑
 */
void initialize_liquid_glass_extension(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    
    ClassDB::register_class<LiquidGlass>();
}

/*
 * uninitialize_liquid_glass_extension() - 扩展清理回调
 *   p_level: Godot 引擎当前的清理级别
 *
 *   当前不需要执行特殊清理：
 *   - LiquidGlass 是 Resource 类，由 Godot 的引用计数系统管理生命周期
 *   - 没有全局状态需要手动释放
 *   - 如果将来添加了全局缓存、线程池等资源，需要在此处清理
 */
void uninitialize_liquid_glass_extension(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

/*
 * liquid_glass_extension_init() - GDExtension C 入口函数
 *
 *   此函数是 Godot 引擎加载 .dll/.so 后调用的第一个函数。
 *   函数签名由 GDExtension 规范定义，必须完全匹配。
 *
 *   参数：
 *   - p_get_proc_address: 函数指针获取接口，用于访问 Godot 内部 API
 *   - p_library: GDExtension 库指针，标识当前加载的扩展
 *   - r_initialization: 输出参数，填充初始化/清理回调函数指针
 *
 *   返回值：
 *   - GDExtensionBool: 初始化是否成功
 *
 *   流程：
 *   1. 创建 GDExtensionBinding::InitObject
 *      - 此对象自动处理与 Godot 引擎的绑定握手
 *   2. 注册初始化函数（initialize_liquid_glass_extension）
 *      - 在 SCENE 级别调用时注册 LiquidGlass 类
 *   3. 注册终止函数（uninitialize_liquid_glass_extension）
 *      - 在引擎退出时清理
 *   4. 设置最低初始化级别为 SCENE
 *      - 确保初始化函数不会在更早的级别被调用
 *   5. 调用 init_obj.init() 完成初始化
 */
extern "C" {
    GDExtensionBool GDE_EXPORT liquid_glass_extension_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
        
        init_obj.register_initializer(initialize_liquid_glass_extension);
        init_obj.register_terminator(uninitialize_liquid_glass_extension);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
        
        return init_obj.init();
    }
}
