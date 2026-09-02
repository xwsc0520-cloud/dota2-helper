@echo off
chcp 65001 >nul
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo 请先运行 run_helper.bat 创建环境并安装依赖。
    pause
    exit /b 1
)

echo 正在启动 Dota 2 GSI 模拟器……
start "" http://127.0.0.1:4000
".venv\Scripts\python.exe" simulator.py --speed 10
