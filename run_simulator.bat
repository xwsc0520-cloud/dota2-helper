@echo off
setlocal

set "CONDA_ENV=d2"

rem 切换到当前 bat 文件所在目录
cd /d "%~dp0"

rem 在 bat 中调用 conda 必须使用 call
call conda activate "%CONDA_ENV%"

if errorlevel 1 (
    echo Conda 环境激活失败：%CONDA_ENV%
    pause
    exit /b 1
)

python simulator.py --speed 10

pause