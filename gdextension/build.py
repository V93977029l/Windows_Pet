#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import shutil
import argparse
from pathlib import Path


def run_command(cmd, cwd=None, verbose=True):
    if verbose:
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
            if verbose:
                print(line, end='')

        process.wait()

        if process.returncode != 0:
            raise subprocess.CalledProcessError(process.returncode, cmd)

        return True
    except subprocess.CalledProcessError as e:
        print(f"命令执行失败: {e}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print(f"错误: 命令未找到 - {' '.join(cmd)}", file=sys.stderr)
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


def copy_with_check(src, dst, description):
    try:
        if os.path.exists(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
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


def verify_godot_cpp(godot_cpp_dir):
    print("\n===== 验证 godot-cpp =====")
    
    checks = [
        ("godot-cpp目录", godot_cpp_dir, os.path.isdir),
        ("SConstruct", os.path.join(godot_cpp_dir, "SConstruct"), os.path.isfile),
        ("include目录", os.path.join(godot_cpp_dir, "include"), os.path.isdir),
        ("src目录", os.path.join(godot_cpp_dir, "src"), os.path.isdir),
    ]

    all_ok = True
    for name, path, check in checks:
        exists = check(path)
        status = "✓" if exists else "✗"
        print(f"  {status} {name}: {path}")
        if not exists:
            all_ok = False

    if not all_ok:
        print("\n错误: godot-cpp 不完整，请确保已正确克隆 godot-cpp 仓库")
        print("建议: git clone https://github.com/godotengine/godot-cpp.git")
    
    return all_ok


def build_godot_cpp(godot_cpp_dir, platform, target, clean=False, force=False, jobs=None):
    print(f"\n===== 编译 godot-cpp [{platform}, {target}] =====")
    
    if jobs is None:
        jobs = os.cpu_count() or 4
    
    lib_name = f"libgodot-cpp.{platform}.{target}.x86_64.lib"
    target_lib = os.path.join(godot_cpp_dir, "bin", lib_name)
    
    if not force and not clean and not need_rebuild([os.path.join(godot_cpp_dir, "src")], target_lib):
        print(f"godot-cpp 缓存有效，跳过编译")
        return True
    
    if clean:
        print("清理 godot-cpp 构建缓存...")
        if not run_command(["scons", "-c"], cwd=godot_cpp_dir, verbose=False):
            print("警告: 清理缓存失败")
    
    cmd = [
        "scons",
        f"platform={platform}",
        f"target={target}",
        f"-j{jobs}",
        "arch=x86_64",
        "generate_bindings=yes"
    ]
    
    print(f"编译命令: {' '.join(cmd)}")
    if not run_command(cmd, cwd=godot_cpp_dir, verbose=False):
        print("godot-cpp 编译失败")
        return False
    
    if os.path.exists(target_lib):
        print(f"✓ godot-cpp 编译成功: {target_lib}")
        return True
    else:
        print(f"错误: 编译产物不存在 - {target_lib}")
        return False


def build_extension(ext_dir, platform, target, godot_cpp_dir, clean=False, force=False, jobs=None):
    print(f"\n===== 编译扩展 [{os.path.basename(ext_dir)}] =====")
    
    if jobs is None:
        jobs = os.cpu_count() or 4
    
    ext_name = os.path.basename(ext_dir).replace("_extension", "")
    dll_name = f"lib{ext_name}.{platform}.{target}.x86_64.dll"
    target_dll = os.path.join(ext_dir, "bin", dll_name)
    
    if not force and not clean and not need_rebuild([os.path.join(ext_dir, "src")], target_dll):
        print(f"扩展缓存有效，跳过编译")
        return True
    
    if clean:
        print("清理扩展构建缓存...")
        if not run_command(["scons", "-c"], cwd=ext_dir, verbose=False):
            print("警告: 清理缓存失败")
    
    cmd = [
        "scons",
        f"platform={platform}",
        f"target={target}",
        f"-j{jobs}",
        "arch=x86_64"
    ]
    
    print(f"编译命令: {' '.join(cmd)}")
    if not run_command(cmd, cwd=ext_dir, verbose=False):
        print(f"扩展编译失败")
        return False
    
    if os.path.exists(target_dll):
        print(f"✓ 扩展编译成功: {target_dll}")
        return True
    else:
        print(f"错误: 编译产物不存在 - {target_dll}")
        return False


def deploy_extension(ext_dir, godot_project_path):
    print("\n===== 部署扩展到 Godot 项目 =====")
    
    ext_name = os.path.basename(ext_dir).replace("_extension", "")
    plugin_dir = os.path.join(godot_project_path, "addons", ext_name)
    plugin_bin_dir = os.path.join(plugin_dir, "bin")
    
    os.makedirs(plugin_bin_dir, exist_ok=True)
    
    gdextension_src = os.path.join(ext_dir, f"{ext_name}.gdextension")
    gdextension_dst = os.path.join(plugin_dir, f"{ext_name}.gdextension")
    copy_with_check(gdextension_src, gdextension_dst, f"{ext_name}.gdextension")
    
    ext_bin_dir = os.path.join(ext_dir, "bin")
    if os.path.exists(ext_bin_dir):
        copy_dir_contents(ext_bin_dir, plugin_bin_dir, ".dll")
    else:
        print(f"警告: 扩展二进制目录不存在 - {ext_bin_dir}")
        return False
    
    print(f"✓ 扩展已部署到: {plugin_dir}")
    return True


def verify_deployment(godot_project_path, plugin_name):
    print("\n===== 验证部署 =====")
    
    plugin_dir = os.path.join(godot_project_path, "addons", plugin_name)
    plugin_bin_dir = os.path.join(plugin_dir, "bin")
    
    gdextension_file = os.path.join(plugin_dir, f"{plugin_name}.gdextension")
    
    checks = [
        ("插件目录", plugin_dir, os.path.isdir),
        ("插件bin目录", plugin_bin_dir, os.path.isdir),
        ("gdextension文件", gdextension_file, os.path.isfile),
    ]
    
    all_ok = True
    for name, path, check in checks:
        exists = check(path)
        status = "✓" if exists else "✗"
        print(f"  {status} {name}: {path}")
        if not exists:
            all_ok = False
    
    dll_files = [f for f in os.listdir(plugin_bin_dir) if f.endswith(".dll")] if os.path.exists(plugin_bin_dir) else []
    if dll_files:
        print(f"\n已部署的 DLL 文件:")
        for dll in dll_files:
            print(f"  ✓ {dll}")
    else:
        print(f"\n警告: 未找到 DLL 文件")
        all_ok = False
    
    if all_ok:
        print("\n所有验证通过！")
    else:
        print("\n警告: 部分验证失败！")
    
    return all_ok


def main():
    parser = argparse.ArgumentParser(description="Godot GDExtension 一键编译脚本")
    parser.add_argument("--clean", action="store_true", help="清理构建缓存后重新编译")
    parser.add_argument("--force", action="store_true", help="强制重新编译，忽略增量检查")
    parser.add_argument("--verify", action="store_true", help="仅验证路径，不编译")
    parser.add_argument("--target", default="template_debug", choices=["template_debug", "template_release"],
                        help="编译目标类型")
    parser.add_argument("--platform", default="windows", choices=["windows", "linux", "macos"],
                        help="目标平台")
    parser.add_argument("-j", "--jobs", type=int, default=None, help="并行编译的线程数")
    parser.add_argument("--skip-godot-cpp", action="store_true", help="跳过 godot-cpp 编译")
    args = parser.parse_args()

    print("========================================")
    print("  Godot GDExtension 一键编译脚本")
    print("========================================")
    
    current_dir = Path(__file__).resolve().parent
    godot_project_path = current_dir / ".." / "transparent-pet"
    godot_cpp_dir = current_dir / "godot-cpp"
    
    print(f"\n当前目录: {current_dir}")
    print(f"Godot项目路径: {godot_project_path}")
    print(f"godot-cpp路径: {godot_cpp_dir}")
    print(f"编译目标: {args.target}")
    print(f"目标平台: {args.platform}")
    if args.jobs:
        print(f"并行线程: {args.jobs}")
    
    if args.verify:
        verify_godot_cpp(godot_cpp_dir)
        verify_deployment(godot_project_path, "mouse_passthrough")
        return 0
    
    if not args.skip_godot_cpp:
        if not verify_godot_cpp(godot_cpp_dir):
            print("错误: godot-cpp 验证失败")
            return 1
        
        if not build_godot_cpp(godot_cpp_dir, args.platform, args.target, args.clean, args.force, args.jobs):
            print("错误: godot-cpp 编译失败")
            return 1
    else:
        print("跳过 godot-cpp 编译")
    
    mouse_passthrough_dir = current_dir / "mouse_passthrough_extension"
    if os.path.exists(mouse_passthrough_dir):
        if not build_extension(mouse_passthrough_dir, args.platform, args.target, godot_cpp_dir, args.clean, args.force, args.jobs):
            print("错误: 扩展编译失败")
            return 1
        
        if not deploy_extension(mouse_passthrough_dir, godot_project_path):
            print("错误: 扩展部署失败")
            return 1
    else:
        print(f"警告: 扩展目录不存在 - {mouse_passthrough_dir}")
        return 1
    
    verify_deployment(godot_project_path, "mouse_passthrough")
    
    print("\n========================================")
    print("  编译完成！")
    print("========================================")
    print("\n提示: 如果 Godot 仍然报错，请尝试：")
    print("  1. 关闭 Godot 编辑器")
    print("  2. 删除 .godot 和 imported 目录")
    print("  3. 重新用 Godot 打开项目")
    print("\n常用命令:")
    print("  python build.py              # 增量编译 debug 版本")
    print("  python build.py --clean      # 清理后重新编译")
    print("  python build.py --force      # 强制重新编译")
    print("  python build.py --target=template_release  # 编译 release 版本")
    print("  python build.py --skip-godot-cpp  # 只编译扩展")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())