# CI: Godot 项目导出脚本
#
# 设计原则：
#   1. 所有参数通过命令行传入，不要用环境变量
#   2. 写一个 .bat 文件来实际执行 godot --export-release（避免 PowerShell GUI 程序交互问题）
#   3. 输出尽量简单，让 CI log 可读
#   4. 遇到错误立即退出（exit 1）
#
# 用法（CI）：
#   powershell -File tools\ci_export.ps1 `
#       -GodotPath "${{ runner.temp }}\godot.exe" `
#       -ProjectDir "${{ github.workspace }}\transparent-pet" `
#       -OutputFile "${{ github.workspace }}\build\windows\TransparentPet.exe"

param(
    [Parameter(Mandatory)]
    [string]$GodotPath,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$OutputFile,

    # 预设名称（export_presets.cfg 中定义）
    [string]$PresetName = "Windows Desktop",

    # 预设中 export_path 指向的目录（Godot 在导出前会检查该目录是否存在）
    [string]$PresetExportDir = ""
)

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " Godot CI Export"
Write-Host "========================================="
Write-Host ""
Write-Host "Godot:      $GodotPath"
Write-Host "Project:    $ProjectDir"
Write-Host "Output:     $OutputFile"
Write-Host "Preset:     $PresetName"
Write-Host ""

# ── 检查 godot.exe ─────────────────────────────────────────────
if (-not (Test-Path $GodotPath)) {
    Write-Error "godot.exe not found: $GodotPath"
    exit 1
}

# ── 检查项目目录 ───────────────────────────────────────────────
if (-not (Test-Path $ProjectDir)) {
    Write-Error "Project directory not found: $ProjectDir"
    exit 1
}
if (-not (Test-Path "$ProjectDir\project.godot")) {
    Write-Error "Missing project.godot in: $ProjectDir"
    exit 1
}

# ── 检查 export_presets.cfg ────────────────────────────────────
$PresetFile = "$ProjectDir\export_presets.cfg"
if (-not (Test-Path $PresetFile)) {
    Write-Error "Missing export_presets.cfg in: $ProjectDir"
    exit 1
}
Write-Host "Preset file: $PresetFile"

# ── 检查预设中配置的 export_path 目录 ─────────────────────────
if ($PresetExportDir -ne "") {
    if (-not (Test-Path $PresetExportDir)) {
        New-Item -ItemType Directory -Force -Path $PresetExportDir | Out-Null
        Write-Host "Preset export dir ensured: $PresetExportDir"
    }
}

# ── 确保输出目录存在 ──────────────────────────────────────────
$OutDir = Split-Path -Parent $OutputFile
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Write-Host "Output dir ensured: $OutDir"
}

# ── 检查导出模板 ───────────────────────────────────────────────
$TemplateDirCandidate = "$env:APPDATA\Godot\export_templates"
if (Test-Path $TemplateDirCandidate) {
    $foundTemplate = Get-ChildItem -Path $TemplateDirCandidate -Recurse -Filter "windows_release_x86_64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundTemplate) {
        Write-Host "Windows release template: OK ($($foundTemplate.FullName))"
    } else {
        Write-Warning "windows_release_x86_64.exe not found under $TemplateDirCandidate"
    }
} else {
    Write-Warning "Godot export templates dir not found: $TemplateDirCandidate"
}

# ── 关键点：通过 .bat 文件执行 Godot 导出 ────────────────────────
#
# 为什么不用 & godot.exe --headless ... ？
#   1. Godot 是 Windows GUI 子系统程序（不是 console 程序）
#   2. PowerShell & 操作符对 GUI 程序不捕获 stdout/stderr
#   3. $LASTEXITCODE 也不会被设置
#   4. 含空格的参数（如 "Windows Desktop"）会被 Start-Process -ArgumentList 拆坏
#
# 为什么用 .bat + cmd.exe？
#   1. .bat 文件里可以任意使用双引号，cmd.exe 正确处理
#   2. cmd.exe 是 console 程序，PowerShell 正确捕获其输出和退出码
#
# ───────────────────────────────────────────────────────────────
$BatchFile = Join-Path $OutDir "godot_export.bat"
$ExportLog = Join-Path $OutDir "godot_export.log"

# 构建批处理文件内容
# 注意：这里用简单的字符串连接 + 显式写入引号，确保最终 .bat 中是带双引号的完整命令行
$qt = [char]34  # 双引号字符
$batCmd = "$qt$GodotPath$qt --headless --path $qt$ProjectDir$qt --export-release $qt$PresetName$qt $qt$OutputFile$qt"

$batContent = @()
$batContent += "@echo off"
$batContent += "setlocal"
$batContent += "echo [godot_export] Running command:"
$batContent += "echo   $batCmd"
$batContent += "echo."
$batContent += "$batCmd"
$batContent += "set GODOT_EXITCODE=%ERRORLEVEL%"
$batContent += "echo."
$batContent += "echo [godot_export] Godot exit code: %GODOT_EXITCODE%"
$batContent += "exit /b %GODOT_EXITCODE%"

# 用 UTF-8 无 BOM 写入，避免 cmd.exe 遇到 BOM 问题
[System.IO.File]::WriteAllLines($BatchFile, $batContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Batch file written: $BatchFile"
Write-Host "Content (first 3 lines shown for log):"
Get-Content $BatchFile -First 3 | ForEach-Object { Write-Host "  $_" }
Write-Host "  ..."
Write-Host ""

# ── 执行批处理文件 ─────────────────────────────────────────────
Write-Host "--- Godot export output ---"

$proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $BatchFile) -Wait -PassThru -RedirectStandardOutput $ExportLog -NoNewWindow
$ExitCode = $proc.ExitCode

# 同时把 log 显示到 CI log
if (Test-Path $ExportLog) {
    Get-Content $ExportLog | ForEach-Object { Write-Host $_ }
}
Write-Host "--- end of Godot output ---"
Write-Host ""
Write-Host "Godot process exit code: $ExitCode"
Write-Host ""

# ── 检查导出结果 ───────────────────────────────────────────────
if (Test-Path $OutputFile) {
    $sizeBytes = (Get-Item $OutputFile).Length
    $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
    Write-Host "SUCCESS: $OutputFile ($sizeMB MB / $sizeBytes bytes)"
    exit 0
} else {
    Write-Error "FAILED: $OutputFile not produced. See log above for details."
    exit 1
}
