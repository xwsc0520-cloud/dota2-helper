@echo off
chcp 65001 >nul
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo 正在创建虚拟环境……
    python -m venv .venv
)

echo 正在安装依赖……
".venv\Scripts\python.exe" -m pip install -r requirements.txt

echo 正在启动程序……
".venv\Scripts\python.exe" app.py

pause