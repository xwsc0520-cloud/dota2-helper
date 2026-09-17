from ahk import AHK
import time

# 连接AHK v2，指定版本和exe路径
ahk = AHK(
    version="v2",
    executable_path=r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
)

def on_key():
    ahk.send_input("q")
    ahk.send_input("w")
    ahk.send_input("e")
    ahk.send_input("r")

# 注册热键，绑定Python函数
ahk.add_hotkey("!q", callback=on_key)

# 启动AHK热键监听线程
ahk.start_hotkeys()
print("监听已启动")

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("退出监听")
    ahk.stop_hotkeys()
