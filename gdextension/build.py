#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Godot GDExtension 一键编译脚本
位置：gdextension/build.py
"""

import os
import sys
import subprocess
import shutil


def run_command(cmd, cwd=None):
    """运行命令并返回结果"""
    print(f"执行命令: {' '.join(cmd)}")
    try:
        # 实时显示命令输出
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        
        # 逐行读取并显示输出
        for line in process.stdout:
            print(line, end='')
        
        # 等待命令执行完成
        process.wait()
        
        if process.returncode != 0:
            raise subprocess.CalledProcessError(process.returncode, cmd)
        
        return True
    except subprocess.CalledProcessError as e:
        print(f"命令执行失败: {e}")
        return False


def main():
    """主函数"""
    print(" Godot GDExtension 一键编译脚本")
    print(" 位置：gdextension/build.py")
    print()

    # 获取当前目录和项目路径
    current_dir = os.path.dirname(os.path.abspath(__file__))
    godot_project_path = os.path.join(current_dir, "..", "transparent-pet")

    # 检查并克隆 godot-cpp
    godot_cpp_dir = os.path.join(current_dir, "godot-cpp")
    if not os.path.exists(godot_cpp_dir):
        print("正在克隆 godot-cpp 仓库...")
        # 尝试使用 SSH 方式
        if not run_command(
            ["git", "clone", "git@github.com:godotengine/godot-cpp.git"],
            cwd=current_dir,
        ):
            print("克隆失败，尝试使用 HTTPS 方式...")
            if not run_command(
                ["git", "clone", "https://github.com/godotengine/godot-cpp.git"],
                cwd=current_dir,
            ):
                print("克隆失败，请手动下载并解压到 godot-cpp 目录")
                return 1

        print("正在切换到 godot-cpp 最新发行版...")
        if not run_command(["git", "checkout", "10.0.0-rc1"], cwd=godot_cpp_dir):
            return 1

    # 构建 godot-cpp
    print("正在构建 godot-cpp...")
    if not run_command(
        ["scons", "platform=windows", "target=template_debug", f"-j{os.cpu_count()}"],
        cwd=godot_cpp_dir,
    ):
        print("godot-cpp 构建失败")
        return 1

    # 构建所有扩展
    print()
    print("正在构建所有扩展...")

    # 构建 mouse_passthrough_extension
    mouse_passthrough_dir = os.path.join(current_dir, "mouse_passthrough_extension")
    if os.path.exists(mouse_passthrough_dir):
        print("正在编译 mouse_passthrough_extension...")
        if not run_command(["scons", "--clean"], cwd=mouse_passthrough_dir):
            return 1
        if not run_command(
            [
                "scons",
                "platform=windows",
                "target=template_debug",
                f"-j{os.cpu_count()}",
            ],
            cwd=mouse_passthrough_dir,
        ):
            print("mouse_passthrough_extension 构建失败")
            return 1

        # 复制编译产物到 Godot 项目
        print("正在复制 mouse_passthrough 产物到 Godot 项目...")
        plugin_name = "mouse_passthrough"
        plugin_dir = os.path.join(godot_project_path, "addons", plugin_name)
        plugin_bin_dir = os.path.join(plugin_dir, "bin")

        # 创建目标目录
        os.makedirs(plugin_dir, exist_ok=True)
        os.makedirs(plugin_bin_dir, exist_ok=True)

        # 复制 .gdextension 文件
        gdextension_file = os.path.join(
            mouse_passthrough_dir, f"{plugin_name}.gdextension"
        )
        if os.path.exists(gdextension_file):
            shutil.copy2(gdextension_file, plugin_dir)

        # 复制编译产物
        bin_dir = os.path.join(mouse_passthrough_dir, "bin")
        if os.path.exists(bin_dir):
            for file in os.listdir(bin_dir):
                if file.endswith(".dll"):
                    shutil.copy2(os.path.join(bin_dir, file), plugin_bin_dir)

    print()
    print(" 所有扩展编译完成！")
    print(" 产物已复制到 Godot 项目的 addons/ 文件夹")
    input("按任意键继续...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
