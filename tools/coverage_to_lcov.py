#!/usr/bin/env python3
"""
把 Godot Coverage 插件生成的 coverage.json 转换成 lcov.info 格式
供 Codecov / genhtml 等工具消费。

用法:
    python coverage_to_lcov.py <coverage.json> [--project-dir <godot_project_dir>] [--out <output_file>]

输入:
    coverage.json 的结构:
    {
      "res://core/some_script.gd": {"10": 2, "15": 1, "20": 0, ...},
      "res://modules/foo.gd": {"5": 1, ...}
    }
    key 是 res:// 路径，value 是 {行号: 命中次数}。

输出:
    lcov.info 格式，文件路径会从 res:// 转成 project-dir/ 下的绝对路径。
"""

import argparse
import json
import os
import sys


def res_to_filesystem(res_path: str, project_dir: str) -> str:
    """把 res://some/script.gd 转成 <project_dir>/some/script.gd 的绝对路径。"""
    if res_path.startswith("res://"):
        rel = res_path[len("res://") :]
    else:
        rel = res_path
    # 统一用正斜杠拆分，再 os.path.join 保证平台正确
    parts = rel.replace("\\", "/").split("/")
    return os.path.abspath(os.path.join(project_dir, *parts))


def convert(coverage_json_path: str, project_dir: str, out_path: str) -> int:
    """执行转换。返回写入 output 中记录的文件总数（不含空文件）。"""
    # utf-8-sig 自动跳过可能存在的 BOM（Godot 在 Windows 上有时会输出带 BOM 的文件）
    with open(coverage_json_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    if not isinstance(data, dict):
        print(
            f"[coverage_to_lcov] coverage.json 顶层不是 object: {type(data).__name__}",
            file=sys.stderr,
        )
        return 0

    records_written = 0
    lines_out: list[str] = []

    for res_path, line_map in data.items():
        if not isinstance(line_map, dict) or not line_map:
            continue

        fs_path = res_to_filesystem(res_path, project_dir)

        # line_map 的 key 是字符串形式的行号，value 是命中次数
        das: list[tuple[int, int]] = []
        lines_hit = 0
        lines_found = 0
        for key, count in line_map.items():
            try:
                line_no = int(key)
            except (TypeError, ValueError):
                continue
            try:
                hit = int(count)
            except (TypeError, ValueError):
                try:
                    hit = int(float(count))
                except (TypeError, ValueError):
                    continue
            das.append((line_no, hit))
            lines_found += 1
            if hit > 0:
                lines_hit += 1

        if not das:
            continue

        # 按行号排序输出
        das.sort(key=lambda x: x[0])

        lines_out.append("TN:godot-gdscript")
        lines_out.append(f"SF:{fs_path}")
        for line_no, hit in das:
            lines_out.append(f"DA:{line_no},{hit}")
        lines_out.append(f"LF:{lines_found}")
        lines_out.append(f"LH:{lines_hit}")
        lines_out.append("end_of_record")
        records_written += 1

    # 写出结果
    out_content = "\n".join(lines_out) + "\n" if lines_out else ""
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(out_content)

    print(f"[coverage_to_lcov] {records_written} file(s), wrote {out_path}")
    return records_written


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert Godot Coverage plugin coverage.json to lcov.info format"
    )
    parser.add_argument("coverage_json", help="coverage.json 文件路径")
    parser.add_argument(
        "--project-dir",
        default=".",
        help="Godot 项目根目录（res:// 对应的物理目录），默认当前目录",
    )
    parser.add_argument(
        "--out",
        default="lcov.info",
        help="输出 lcov.info 路径，默认 ./lcov.info",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.coverage_json):
        print(
            f"[coverage_to_lcov] 找不到 coverage.json: {args.coverage_json}",
            file=sys.stderr,
        )
        return 1

    count = convert(args.coverage_json, args.project_dir, args.out)

    if count == 0:
        print(
            "[coverage_to_lcov] 未找到任何覆盖率记录（可能是测试未运行或 coverage.json 为空）",
            file=sys.stderr,
        )
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
