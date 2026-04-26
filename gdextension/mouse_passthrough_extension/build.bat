@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo ==============================================
echo  Godot GDExtension 多插件自动编译脚本
echo  位置：gdextension/build.bat
echo ==============================================
echo.

:: 自动编译当前目录下 所有子文件夹（跳过 godot-cpp）
for /d %%D in (*) do (
    set "folder=%%D"
    
    :: 跳过库文件夹
    if /i not "!folder!"=="godot-cpp" (
        echo ==================================================
        echo  正在编译插件：!folder!
        echo ==================================================
        
        cd "!folder!"
        
        :: 清理 + 编译（Windows x64 调试版）
        scons --clean
        scons platform=windows target=template_debug -j%NUMBER_OF_PROCESSORS%
        
        cd ..
        echo.
    )
)

echo ==============================================
echo  所有插件编译完成！
echo  产物在每个插件的 bin/ 文件夹
echo ==============================================
pause