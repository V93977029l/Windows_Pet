#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import shutil
import argparse


def run_command(cmd, cwd=None):
    print(f"执行命令: {' '.join(cmd)}")
    try:
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        for line in process.stdout:
            print(line, end='')

        process.wait()

        if process.returncode != 0:
            raise subprocess.CalledProcessError(process.returncode, cmd)

        return True
    except subprocess.CalledProcessError as e:
        print(f"命令执行失败: {e}")
        return False


def get_modification_time(path):
    try:
        if os.path.isfile(path):
            return os.path.getmtime(path)
        elif os.path.isdir(path):
            max_mtime = 0
            for root, dirs, files in os.walk(path):
                for f in files:
                    f_path = os.path.join(root, f)
                    try:
                        mtime = os.path.getmtime(f_path)
                        if mtime > max_mtime:
                            max_mtime = mtime
                    except OSError:
                        pass
            return max_mtime
        return 0
    except OSError:
        return 0


def need_rebuild(source_dirs, target_file):
    if not os.path.exists(target_file):
        return True

    target_mtime = os.path.getmtime(target_file)

    for src_dir in source_dirs:
        src_mtime = get_modification_time(src_dir)
        if src_mtime > target_mtime:
            print(f"检测到 {src_dir} 有更新，需要重新编译")
            return True

    print("源文件未修改，跳过编译")
    return False


def verify_paths(godot_project_path, plugin_name):
    print("\n===== 路径验证 =====")

    plugin_dir = os.path.join(godot_project_path, "addons", plugin_name)
    plugin_bin_dir = os.path.join(plugin_dir, "bin")

    gdextension_file = os.path.join(plugin_dir, f"{plugin_name}.gdextension")
    dll_file = os.path.join(plugin_bin_dir, "libmouse_passthrough.windows.template_debug.x86_64.dll")

    checks = [
        ("插件目录", plugin_dir, os.path.isdir),
        ("插件bin目录", plugin_bin_dir, os.path.isdir),
        ("gdextension文件", gdextension_file, os.path.isfile),
        ("dll文件", dll_file, os.path.isfile),
    ]

    all_ok = True
    for name, path, check in checks:
        exists = check(path)
        status = "✓" if exists else "✗"
        print(f"  {status} {name}: {path}")
        if not exists:
            all_ok = False

    if os.path.isfile(gdextension_file):
        with open(gdextension_file, 'r') as f:
            content = f.read()
        
        if 'windows.template_debug.x86_64' in content or 'windows.template_release.x86_64' in content:
            print("\n警告: .gdextension 文件中使用了错误的库键名！")
            print("  错误格式: windows.template_debug.x86_64")
            print("  正确格式: windows.debug.x86_64")
            all_ok = False

    if all_ok:
        print("\n所有路径验证通过！")
    else:
        print("\n警告: 部分验证失败！")

    return all_ok


def copy_with_check(src, dst, description):
    try:
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"已复制: {description}")
            return True
        else:
            print(f"警告: 源文件不存在 - {src}")
            return False
    except Exception as e:
        print(f"复制失败 ({description}): {e}")
        return False


def copy_dir_contents(src_dir, dst_dir, file_pattern=None):
    try:
        os.makedirs(dst_dir, exist_ok=True)
        copied = False

        for filename in os.listdir(src_dir):
            if file_pattern and not filename.endswith(file_pattern):
                continue

            src_path = os.path.join(src_dir, filename)
            dst_path = os.path.join(dst_dir, filename)

            if os.path.isfile(src_path):
                shutil.copy2(src_path, dst_path)
                print(f"已复制: {filename}")
                copied = True

        return copied
    except Exception as e:
        print(f"复制目录内容失败: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Godot GDExtension 一键编译脚本")
    parser.add_argument("--clean", action="store_true", help="清理构建缓存后重新编译")
    parser.add_argument("--force", action="store_true", help="强制重新编译，忽略增量检查")
    parser.add_argument("--verify", action="store_true", help="仅验证路径，不编译")
    args = parser.parse_args()

    print(" Godot GDExtension 一键编译脚本")
    print(" 位置：gdextension/build.py")
    print()

    current_dir = os.path.dirname(os.path.abspath(__file__))
    godot_project_path = os.path.join(current_dir, "..", "transparent-pet")
    godot_cpp_dir = os.path.join(current_dir, "godot-cpp")

    print(f"当前目录: {current_dir}")
    print(f"Godot项目路径: {godot_project_path}")
    print(f"godot-cpp路径: {godot_cpp_dir}")
    print()

    if args.verify:
        verify_paths(godot_project_path, "mouse_passthrough")
        return 0

    if not os.path.exists(godot_cpp_dir):
        print(f"错误: godot-cpp 目录不存在 - {godot_cpp_dir}")
        return 1

    if not os.path.exists(godot_project_path):
        print(f"错误: Godot项目目录不存在 - {godot_project_path}")
        return 1

    godot_cpp_lib = os.path.join(godot_cpp_dir, "bin", "libgodot-cpp.windows.template_debug.x86_64.lib")

    if args.clean:
        print("清理 godot-cpp 构建缓存...")
        if not run_command(["scons", "-c"], cwd=godot_cpp_dir):
            print("警告: 清理 godot-cpp 缓存失败")

    if args.force or need_rebuild([os.path.join(godot_cpp_dir, "include"), os.path.join(godot_cpp_dir, "src")], godot_cpp_lib):
        print("正在构建 godot-cpp...")
        if not run_command(
            ["scons", "platform=windows", "target=template_debug", f"-j{os.cpu_count()}"],
            cwd=godot_cpp_dir,
        ):
            print("godot-cpp 构建失败")
            return 1
    else:
        print("跳过 godot-cpp 编译（缓存有效）")

    print()
    print("正在构建所有扩展...")

    mouse_passthrough_dir = os.path.join(current_dir, "mouse_passthrough_extension")

    if os.path.exists(mouse_passthrough_dir):
        print(f"mouse_passthrough_extension 路径: {mouse_passthrough_dir}")

        mouse_passthrough_dll = os.path.join(mouse_passthrough_dir, "bin", "libmouse_passthrough.windows.template_debug.x86_64.dll")

        if args.clean:
            print("清理 mouse_passthrough_extension 构建缓存...")
            if not run_command(["scons", "-c"], cwd=mouse_passthrough_dir):
                print("警告: 清理扩展缓存失败")

        if args.force or need_rebuild([os.path.join(mouse_passthrough_dir, "src")], mouse_passthrough_dll):
            print("正在编译 mouse_passthrough_extension...")
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
        else:
            print("跳过 mouse_passthrough_extension 编译（缓存有效）")

        print("正在复制 mouse_passthrough 产物到 Godot 项目...")
        plugin_name = "mouse_passthrough"
        plugin_dir = os.path.join(godot_project_path, "addons", plugin_name)
        plugin_bin_dir = os.path.join(plugin_dir, "bin")

        print(f"目标插件目录: {plugin_dir}")
        print(f"目标二进制目录: {plugin_bin_dir}")

        os.makedirs(plugin_dir, exist_ok=True)
        os.makedirs(plugin_bin_dir, exist_ok=True)

        gdextension_file = os.path.join(mouse_passthrough_dir, f"{plugin_name}.gdextension")
        copy_with_check(gdextension_file, plugin_dir, f"{plugin_name}.gdextension")

        bin_dir = os.path.join(mouse_passthrough_dir, "bin")
        if os.path.exists(bin_dir):
            copy_dir_contents(bin_dir, plugin_bin_dir, ".dll")
        else:
            print(f"警告: 编译产物目录不存在 - {bin_dir}")

    print()
    print(" 所有扩展编译完成！")

    verify_paths(godot_project_path, "mouse_passthrough")

    print()
    print("提示: 如果 Godot 仍然报错，请尝试：")
    print("  1. 关闭 Godot 编辑器")
    print("  2. 删除 .godot 和 imported 目录")
    print("  3. 重新用 Godot 打开项目")

    input("按任意键继续...")
    return 0


if __name__ == "__main__":
    sys.exit(main())