#!/usr/bin/env -S godot -s
## 覆盖率测试运行器
## 用法: godot --headless --path . -s res://tools/coverage_runner.gd -a res://tests/ -c --ignoreHeadlessMode
## 输出: test-reports/coverage.json, test-reports/coverage-summary.txt

extends SceneTree

const Coverage = preload("res://addons/coverage/coverage.gd")

var _cli_runner: GdUnitTestCIRunner
var _exit_code := 0


func _initialize() -> void:
	# 初始化覆盖率 — 只扫描 core/ 和 modules/ 源码目录
	Coverage.new(self, [])
	Coverage.instance.instrument_scripts("res://core")
	Coverage.instance.instrument_scripts("res://modules")

	# 启动 GdUnit4 CLI 测试运行器
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	_cli_runner = GdUnitTestCIRunner.new()
	root.add_child(_cli_runner)


func _finalize() -> void:
	_exit_code = _cli_runner.get_exit_code() if _cli_runner else 0
	_save_coverage()
	queue_delete(_cli_runner)


func _save_coverage() -> void:
	var report_dir := "test-reports"
	DirAccess.make_dir_recursive_absolute(report_dir)

	var coverage_file: String = report_dir.path_join("coverage.json")
	Coverage.instance.save_coverage_file(coverage_file)

	Coverage.instance.set_coverage_targets(0.0, 0.0)
	var summary: String = Coverage.instance.script_coverage(Coverage.Verbosity.FILENAMES)
	var summary_file: String = report_dir.path_join("coverage-summary.txt")

	var f: FileAccess = FileAccess.open(summary_file, FileAccess.WRITE)
	if f:
		f.store_string(summary)

	prints("Coverage report:", coverage_file)
	print(summary)
