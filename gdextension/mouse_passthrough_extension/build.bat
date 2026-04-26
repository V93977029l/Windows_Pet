@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo ==============================================
echo  Godot GDExtension 插件编译脚本
echo  位置：mouse_passthrough_extension/build.bat
echo ==============================================
echo.

:: Godot 项目路径
set "GODOT_PROJECT_PATH=f:\VSCode\game\transparent-pet"

:: 插件名称
set "PLUGIN_NAME=mouse_passthrough"

:: 清理 + 编译（Windows x64 调试版）
echo 正在编译插件：%PLUGIN_NAME%
echo ==================================================
scons --clean
scons platform=windows target=template_debug -j%NUMBER_OF_PROCESSORS%

:: 复制编译产物到 Godot 项目
echo 正在复制编译产物到 Godot 项目...

:: 创建目标目录
if not exist "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%" mkdir "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%"
if not exist "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%\bin" mkdir "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%\bin"

:: 复制 .gdextension 文件
if exist "%PLUGIN_NAME%.gdextension" copy "%PLUGIN_NAME%.gdextension" "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%\"

:: 复制编译产物
if exist "bin\*.dll" copy "bin\*.dll" "%GODOT_PROJECT_PATH%\addons\%PLUGIN_NAME%\bin\"

echo.
echo ==============================================
echo  插件编译完成！
echo  产物已复制到 Godot 项目的 addons/%PLUGIN_NAME%/ 文件夹
echo ==============================================
pause