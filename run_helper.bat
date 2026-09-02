@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "CONDA_ENV=d2"
set "PYTHON_VERSION=3.10"

echo [1/4] 正在检查 Conda……
where conda >nul 2>&1
if errorlevel 1 (
    echo.
    echo 错误：未找到 Conda。
    echo 请先安装 Anaconda 或 Miniconda，并确保可以在命令行运行 conda。
    goto :error
)

echo [2/4] 正在检查 Conda 环境 %CONDA_ENV%……
call conda run -n "%CONDA_ENV%" python --version >nul 2>&1

if errorlevel 1 (
    echo 环境 %CONDA_ENV% 不存在，正在自动创建……
    call conda create -n "%CONDA_ENV%" python=%PYTHON_VERSION% pip -y
    if errorlevel 1 (
        echo 错误：创建 Conda 环境失败。
        goto :error
    )
) else (
    echo Conda 环境 %CONDA_ENV% 已存在。
)

if not exist "requirements.txt" (
    echo.
    echo 错误：当前目录下没有 requirements.txt。
    goto :error
)

if not exist "app.py" (
    echo.
    echo 错误：当前目录下没有 app.py。
    goto :error
)

echo [3/4] 正在安装和检查依赖……
call conda run -n "%CONDA_ENV%" python -m pip install -r requirements.txt
if errorlevel 1 (
    echo 错误：依赖安装失败。
    goto :error
)

echo.
echo [4/4] 正在启动 Dota 2 提示工具……
echo.
call conda run --no-capture-output -n "%CONDA_ENV%" python app.py
if errorlevel 1 (
    echo.
    echo 错误：程序运行失败。
    goto :error
)

exit /b 0

:error
echo.
echo 启动失败，请检查上面的错误信息。
pause
exit /b 1