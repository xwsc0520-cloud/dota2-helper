# Dota 2 提示工具与 GSI 模拟器

本项目不需要安装 Dota 2。模拟器会生成类似 Dota 2 Game State
Integration 的 JSON，并发送给本地提示工具。

## 环境要求

- Python 3.9 或更新版本
- Windows、macOS 或 Linux

## Windows 快速启动

1. 双击 `run_helper.bat`
2. 再双击 `run_simulator.bat`
3. 打开：
   - 提示工具：http://127.0.0.1:3000
   - 模拟器：http://127.0.0.1:4000
4. 在模拟器页面点击“开始”

默认速度是 10 倍：

- 现实约 1 秒 = 游戏 10 秒
- 现实约 1 秒后触发 10 秒测试提醒
- 现实约 16 秒后触发 2:40 莲花提前提醒
- 现实约 18 秒后触发 3:00 莲花刷新提醒

## macOS/Linux 快速启动

第一个终端：

```bash
chmod +x run_helper.sh run_simulator.sh
./run_helper.sh
