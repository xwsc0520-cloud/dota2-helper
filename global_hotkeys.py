import sys

if sys.platform != "win32":
    raise RuntimeError("global_hotkeys 只能在 Windows 上运行")

import ctypes
import queue
import signal
import threading
from ctypes import wintypes
import time
import random


# ============================================================
# Windows DLL
# ============================================================

user32 = ctypes.WinDLL(
    "user32",
    use_last_error=True,
)

kernel32 = ctypes.WinDLL(
    "kernel32",
    use_last_error=True,
)


# ============================================================
# Windows 常量
# ============================================================

WH_KEYBOARD_LL = 13

WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
WM_SYSKEYDOWN = 0x0104
WM_SYSKEYUP = 0x0105
WM_QUIT = 0x0012

# 通用修饰键
VK_SHIFT = 0x10
VK_CONTROL = 0x11
VK_MENU = 0x12

# 左右修饰键
VK_LSHIFT = 0xA0
VK_RSHIFT = 0xA1
VK_LCONTROL = 0xA2
VK_RCONTROL = 0xA3
VK_LMENU = 0xA4
VK_RMENU = 0xA5

# 低级键盘钩子标志
LLKHF_EXTENDED = 0x01
LLKHF_INJECTED = 0x10

# SendInput
INPUT_KEYBOARD = 1

KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004

ULONG_PTR = ctypes.c_size_t
LRESULT = ctypes.c_ssize_t


# ============================================================
# Windows 数据结构
# ============================================================

class KBDLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [
        ("vkCode", wintypes.DWORD),
        ("scanCode", wintypes.DWORD),
        ("flags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD),
    ]


class INPUT_UNION(ctypes.Union):
    _fields_ = [
        ("mi", MOUSEINPUT),
        ("ki", KEYBDINPUT),
        ("hi", HARDWAREINPUT),
    ]


class INPUT(ctypes.Structure):
    _anonymous_ = ("u",)

    _fields_ = [
        ("type", wintypes.DWORD),
        ("u", INPUT_UNION),
    ]


LowLevelKeyboardProc = ctypes.WINFUNCTYPE(
    LRESULT,
    ctypes.c_int,
    wintypes.WPARAM,
    wintypes.LPARAM,
)


# ============================================================
# Windows API 函数签名
# ============================================================

user32.SetWindowsHookExW.argtypes = [
    ctypes.c_int,
    LowLevelKeyboardProc,
    wintypes.HINSTANCE,
    wintypes.DWORD,
]
user32.SetWindowsHookExW.restype = wintypes.HHOOK

user32.CallNextHookEx.argtypes = [
    wintypes.HHOOK,
    ctypes.c_int,
    wintypes.WPARAM,
    wintypes.LPARAM,
]
user32.CallNextHookEx.restype = LRESULT

user32.UnhookWindowsHookEx.argtypes = [
    wintypes.HHOOK,
]
user32.UnhookWindowsHookEx.restype = wintypes.BOOL

user32.SendInput.argtypes = [
    wintypes.UINT,
    ctypes.POINTER(INPUT),
    ctypes.c_int,
]
user32.SendInput.restype = wintypes.UINT

user32.GetMessageW.argtypes = [
    ctypes.POINTER(wintypes.MSG),
    wintypes.HWND,
    wintypes.UINT,
    wintypes.UINT,
]
user32.GetMessageW.restype = wintypes.BOOL

user32.TranslateMessage.argtypes = [
    ctypes.POINTER(wintypes.MSG),
]
user32.TranslateMessage.restype = wintypes.BOOL

user32.DispatchMessageW.argtypes = [
    ctypes.POINTER(wintypes.MSG),
]
user32.DispatchMessageW.restype = LRESULT

user32.PostThreadMessageW.argtypes = [
    wintypes.DWORD,
    wintypes.UINT,
    wintypes.WPARAM,
    wintypes.LPARAM,
]
user32.PostThreadMessageW.restype = wintypes.BOOL

kernel32.GetModuleHandleW.argtypes = [
    wintypes.LPCWSTR,
]
kernel32.GetModuleHandleW.restype = wintypes.HMODULE

kernel32.GetCurrentThreadId.argtypes = []
kernel32.GetCurrentThreadId.restype = wintypes.DWORD


# ============================================================
# 普通按键名称
# ============================================================

SPECIAL_KEYS = {
    "space": 0x20,
    "tab": 0x09,

    "enter": 0x0D,
    "return": 0x0D,

    "esc": 0x1B,
    "escape": 0x1B,

    "backspace": 0x08,

    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,

    "insert": 0x2D,
    "delete": 0x2E,

    "home": 0x24,
    "end": 0x23,

    "pageup": 0x21,
    "pagedown": 0x22,
    "pgup": 0x21,
    "pgdn": 0x22,

    "capslock": 0x14,
    "numlock": 0x90,
    "scrolllock": 0x91,

    "pause": 0x13,

    "numpad0": 0x60,
    "numpad1": 0x61,
    "numpad2": 0x62,
    "numpad3": 0x63,
    "numpad4": 0x64,
    "numpad5": 0x65,
    "numpad6": 0x66,
    "numpad7": 0x67,
    "numpad8": 0x68,
    "numpad9": 0x69,
}


MODIFIER_ALIASES = {
    "alt": "alt",
    "option": "alt",

    "ctrl": "ctrl",
    "control": "ctrl",

    "shift": "shift",
}


MODIFIER_ORDER = {
    "ctrl": 0,
    "shift": 1,
    "alt": 2,
}


def key_name_to_vk(key_name):
    """
    将按键名称转换为 Windows 虚拟键码。

    支持：
        a-z
        0-9
        f1-f24
        space
        enter
        tab
        esc
        backspace
        方向键
        pageup / pagedown
        numpad0-numpad9
    """

    if not isinstance(key_name, str):
        raise TypeError("按键名称必须是字符串")

    key_name = key_name.strip().lower()

    if not key_name:
        raise ValueError("按键名称不能为空")

    # A-Z、0-9
    if len(key_name) == 1:
        character = key_name.upper()

        if "A" <= character <= "Z":
            return ord(character)

        if "0" <= character <= "9":
            return ord(character)

    # F1-F24
    if key_name.startswith("f"):
        number_text = key_name[1:]

        if number_text.isdigit():
            number = int(number_text)

            if 1 <= number <= 24:
                return 0x70 + number - 1

    if key_name in SPECIAL_KEYS:
        return SPECIAL_KEYS[key_name]

    raise ValueError(
        f"不支持的触发键：{key_name!r}"
    )


def vk_to_name(vk_code):
    if ord("A") <= vk_code <= ord("Z"):
        return chr(vk_code)

    if ord("0") <= vk_code <= ord("9"):
        return chr(vk_code)

    if 0x70 <= vk_code <= 0x87:
        return f"F{vk_code - 0x70 + 1}"

    preferred_names = {
        0x20: "SPACE",
        0x09: "TAB",
        0x0D: "ENTER",
        0x1B: "ESC",
        0x08: "BACKSPACE",

        0x25: "LEFT",
        0x26: "UP",
        0x27: "RIGHT",
        0x28: "DOWN",

        0x2D: "INSERT",
        0x2E: "DELETE",

        0x24: "HOME",
        0x23: "END",

        0x21: "PAGEUP",
        0x22: "PAGEDOWN",
    }

    if vk_code in preferred_names:
        return preferred_names[vk_code]

    return f"VK_{vk_code:02X}"


# ============================================================
# 全局快捷键管理器
# ============================================================

class GlobalHotkeys:
    def __init__(self):
        # 映射格式：
        #
        # {
        #     (frozenset({"shift"}), VK_Q): "qqqrd",
        #     (frozenset({"ctrl", "shift"}), VK_W): "hello",
        # }
        self._mappings = {}

        # 当前实际按下的物理修饰键。
        #
        # 保存左右键的具体虚拟键码，例如：
        # {
        #     VK_LSHIFT,
        #     VK_RCONTROL,
        # }
        #
        # 使用具体虚拟键码，可以正确处理左右 Shift 同时按下。
        self._pressed_modifier_keys = set()

        # 当前所有映射使用到的修饰键名称。
        #
        # 例如：
        # {"shift", "ctrl"}
        #
        # 这些修饰键会被全局吞掉。
        self._used_modifiers = set()

        # 已经触发，但尚未收到物理松开事件的触发键。
        #
        # 用于：
        # 1. 阻止键盘自动重复
        # 2. 吞掉对应的松开事件
        self._consumed_keys = set()

        # 自动输入工作队列。
        self._action_queue = queue.Queue()

        self._worker_thread = None
        self._hook_handle = None

        self._running = False
        self._message_thread_id = None

        # 必须保存回调引用，防止被垃圾回收。
        self._keyboard_callback = LowLevelKeyboardProc(
            self._hook_callback
        )

        self._run_thread = None
        self._started_event = threading.Event()
        self._stopped_event = threading.Event()

    # ========================================================
    # 公共接口
    # ========================================================

    def register(self, hotkey, output, interval=0.0):
        """
        注册快捷键映射。

        interval：字符之间的间隔，单位为秒。

        示例：
            register("alt+q", "qqqrd", interval=0.03)
        """

        if self._running:
            raise RuntimeError(
                "监听已经启动，不能在 run() 之后注册快捷键"
            )

        if not isinstance(output, str):
            raise TypeError("output 必须是字符串")

        if not isinstance(interval, (int, float)):
            raise TypeError("interval 必须是数字")

        if interval < 0:
            raise ValueError("interval 不能小于 0")

        modifiers, trigger_name = self._parse_hotkey(hotkey)
        trigger_vk = key_name_to_vk(trigger_name)

        mapping_key = (
            frozenset(modifiers),
            trigger_vk,
        )

        # 保存输出文本和字符间隔
        self._mappings[mapping_key] = (
            output,
            float(interval),
        )

        self._recalculate_used_modifiers()
        return self

    def bind(self, hotkey, output, interval=0.0):
        return self.register(
            hotkey,
            output,
            interval=interval,
        )

    def unregister(self, hotkey):
        """
        删除快捷键映射。

        示例：
            manager.unregister("shift+q")
        """

        if self._running:
            raise RuntimeError(
                "监听已经启动，不能在 run() 之后删除快捷键"
            )

        modifiers, trigger_name = self._parse_hotkey(
            hotkey
        )

        trigger_vk = key_name_to_vk(trigger_name)

        mapping_key = (
            frozenset(modifiers),
            trigger_vk,
        )

        self._mappings.pop(mapping_key, None)
        self._recalculate_used_modifiers()

        return self

    def clear(self):
        """
        删除所有映射。
        """

        if self._running:
            raise RuntimeError(
                "监听已经启动，不能在 run() 之后清空映射"
            )

        self._mappings.clear()
        self._used_modifiers.clear()

        return self

    def start(self, timeout=5.0):
        """
        在后台线程启动监听，不阻塞调用线程。

        返回 self，可以链式调用。
        """

        if self._running:
            return

        if self._run_thread is not None and self._run_thread.is_alive():
            raise RuntimeError("快捷键监听线程已经存在")

        if not self._mappings:
            raise RuntimeError("尚未注册任何快捷键")

        self._started_event.clear()
        self._stopped_event.clear()

        self._run_thread = threading.Thread(
            target=self._background_run,
            name="GlobalHotkeyMessageThread",
            daemon=True,
        )

        self._run_thread.start()

        if not self._started_event.wait(timeout):
            raise TimeoutError("启动全局快捷键监听超时")

        return self

    def _background_run(self):
        try:
            self.run()
        except Exception as error:
            print(f"全局快捷键监听异常：{error}")
            self._started_event.set()
        finally:
            self._stopped_event.set()

    def wait(self, timeout=None):
        """
        等待监听停止。

        timeout:
            None 表示一直等待；
            数字表示最多等待多少秒。

        返回：
            True：已经停止
            False：等待超时
        """

        return self._stopped_event.wait(timeout)

    def join(self, timeout=None):
        """
        等待后台监听线程结束。
        """

        thread = self._run_thread

        if thread is not None:
            thread.join(timeout)

            if not thread.is_alive():
                self._run_thread = None
                return True

            return False

        return True

    def run(self):
        """
        启动全局快捷键监听。

        此方法会阻塞当前线程。
        通常应在主线程调用。
        """

        if self._running:
            return

        if not self._mappings:
            raise RuntimeError("尚未注册任何快捷键")

        self._validate_input_structure()

        old_signal_handler = None
        signal_handler_installed = False

        try:
            self._start_worker()
            self._install_hook()

            self._running = True
            self._message_thread_id = (
                kernel32.GetCurrentThreadId()
            )

            self._started_event.set()

            # signal.signal() 只能在 Python 主线程调用。
            if (
                threading.current_thread()
                is threading.main_thread()
            ):
                old_signal_handler = signal.getsignal(
                    signal.SIGINT
                )

                signal.signal(
                    signal.SIGINT,
                    self._signal_stop_handler,
                )

                signal_handler_installed = True

            self._print_mappings()
            self._message_loop()

        finally:
            self._started_event.set()

            if signal_handler_installed:
                signal.signal(
                    signal.SIGINT,
                    old_signal_handler,
                )

            self._cleanup()

    def stop(self):
        """
        请求停止监听。

        可以从其他线程调用。
        """

        if not self._running:
            return

        thread_id = self._message_thread_id

        if thread_id is not None:
            success = user32.PostThreadMessageW(
                thread_id,
                WM_QUIT,
                0,
                0,
            )

            if not success:
                error_code = ctypes.get_last_error()

                print(
                    f"停止监听失败："
                    f"PostThreadMessageW 错误码 {error_code}"
                )

    # ========================================================
    # 快捷键解析
    # ========================================================

    @staticmethod
    def _parse_hotkey(hotkey):
        if not isinstance(hotkey, str):
            raise TypeError("hotkey 必须是字符串")

        parts = [
            part.strip().lower()
            for part in hotkey.split("+")
            if part.strip()
        ]

        if len(parts) < 2:
            raise ValueError(
                "快捷键必须包含修饰键和触发键，"
                "例如 'shift+q' 或 'ctrl+shift+w'"
            )

        trigger_key = parts[-1]
        modifier_parts = parts[:-1]

        modifiers = set()

        for part in modifier_parts:
            modifier = MODIFIER_ALIASES.get(part)

            if modifier is None:
                raise ValueError(
                    f"不支持的修饰键：{part!r}；"
                    "目前支持 alt、ctrl、shift"
                )

            if modifier in modifiers:
                raise ValueError(
                    f"修饰键重复：{part!r}"
                )

            modifiers.add(modifier)

        if not modifiers:
            raise ValueError(
                "快捷键至少需要一个修饰键"
            )

        return modifiers, trigger_key

    def _recalculate_used_modifiers(self):
        self._used_modifiers.clear()

        for modifiers, _ in self._mappings:
            self._used_modifiers.update(modifiers)

    # ========================================================
    # 修饰键状态
    # ========================================================

    @staticmethod
    def _normalize_modifier_vk(event):
        """
        将通用的 Shift/Ctrl/Alt 转换成具体的左右键。
        """

        vk_code = event.vkCode

        if vk_code in (
            VK_LSHIFT,
            VK_RSHIFT,
            VK_LCONTROL,
            VK_RCONTROL,
            VK_LMENU,
            VK_RMENU,
        ):
            return vk_code

        if vk_code == VK_SHIFT:
            # 常见扫描码：
            # 左 Shift：0x2A
            # 右 Shift：0x36
            if event.scanCode == 0x36:
                return VK_RSHIFT

            return VK_LSHIFT

        if vk_code == VK_CONTROL:
            if event.flags & LLKHF_EXTENDED:
                return VK_RCONTROL

            return VK_LCONTROL

        if vk_code == VK_MENU:
            if event.flags & LLKHF_EXTENDED:
                return VK_RMENU

            return VK_LMENU

        return None

    @staticmethod
    def _modifier_vk_to_name(vk_code):
        if vk_code in (
            VK_LSHIFT,
            VK_RSHIFT,
        ):
            return "shift"

        if vk_code in (
            VK_LCONTROL,
            VK_RCONTROL,
        ):
            return "ctrl"

        if vk_code in (
            VK_LMENU,
            VK_RMENU,
        ):
            return "alt"

        return None

    def _get_active_modifiers(self):
        """
        返回当前物理按下的修饰键名称集合。
        """

        active = set()

        for vk_code in self._pressed_modifier_keys:
            name = self._modifier_vk_to_name(vk_code)

            if name is not None:
                active.add(name)

        return active

    # ========================================================
    # SendInput
    # ========================================================

    @staticmethod
    def _make_unicode_input(code_unit, key_up=False):
        flags = KEYEVENTF_UNICODE

        if key_up:
            flags |= KEYEVENTF_KEYUP

        keyboard_input = KEYBDINPUT(
            wVk=0,
            wScan=code_unit,
            dwFlags=flags,
            time=0,
            dwExtraInfo=0,
        )

        return INPUT(
            type=INPUT_KEYBOARD,
            u=INPUT_UNION(
                ki=keyboard_input
            ),
        )

    def _send_unicode_text(self, text, interval=0.0):
        """
        输入 Unicode 文本。

        interval：
            相邻字符之间的间隔，单位为秒。

        例如：
            interval=0.03 表示间隔 30 毫秒。
        """

        encoded = text.encode("utf-16-le")

        code_units = [
            encoded[index]
            | (encoded[index + 1] << 8)
            for index in range(0, len(encoded), 2)
        ]

        for index, code_unit in enumerate(code_units):
            # 同一个字符的按下和松开一起发送
            events = [
                self._make_unicode_input(
                    code_unit,
                    key_up=False,
                ),
                self._make_unicode_input(
                    code_unit,
                    key_up=True,
                ),
            ]

            input_array = (INPUT * len(events))(*events)

            ctypes.set_last_error(0)

            sent_count = user32.SendInput(
                len(events),
                input_array,
                ctypes.sizeof(INPUT),
            )

            if sent_count != len(events):
                error_code = ctypes.get_last_error()

                print(
                    f"SendInput 失败："
                    f"发送了 {sent_count}/{len(events)}，"
                    f"错误码 {error_code}"
                )

                return

            # 最后一个字符后面不再等待
            if interval > 0 and index < len(code_units) - 1:
                r = random.random() * interval * 0.5
                time.sleep(interval + r)

    # ========================================================
    # 自动输入工作线程
    # ========================================================

    def _start_worker(self):
        if self._worker_thread is not None:
            return

        self._worker_thread = threading.Thread(
            target=self._input_worker,
            name="GlobalHotkeyInputWorker",
            daemon=True,
        )

        self._worker_thread.start()

    def _input_worker(self):
        while True:
            task = self._action_queue.get()

            try:
                if task is None:
                    return

                output, interval = task

                self._send_unicode_text(
                    output,
                    interval=interval,
                )

            except Exception as error:
                print(f"自动输入失败：{error}")

            finally:
                self._action_queue.task_done()

    # ========================================================
    # 低级键盘钩子
    # ========================================================

    @staticmethod
    def _call_next_hook(
        n_code,
        w_param,
        l_param,
    ):
        return user32.CallNextHookEx(
            None,
            n_code,
            w_param,
            l_param,
        )

    def _hook_callback(
        self,
        n_code,
        w_param,
        l_param,
    ):
        if n_code < 0:
            return self._call_next_hook(
                n_code,
                w_param,
                l_param,
            )

        event = ctypes.cast(
            l_param,
            ctypes.POINTER(KBDLLHOOKSTRUCT),
        ).contents

        message = int(w_param)

        is_key_down = message in (
            WM_KEYDOWN,
            WM_SYSKEYDOWN,
        )

        is_key_up = message in (
            WM_KEYUP,
            WM_SYSKEYUP,
        )

        # SendInput 创建的事件会携带 LLKHF_INJECTED。
        #
        # 这些事件必须放行，并且不能再次参与快捷键检测，
        # 否则程序可能触发自己。
        if event.flags & LLKHF_INJECTED:
            return self._call_next_hook(
                n_code,
                w_param,
                l_param,
            )

        vk_code = event.vkCode

        # ----------------------------------------------------
        # 处理修饰键
        # ----------------------------------------------------

        normalized_modifier_vk = (
            self._normalize_modifier_vk(event)
        )

        if normalized_modifier_vk is not None:
            modifier_name = (
                self._modifier_vk_to_name(
                    normalized_modifier_vk
                )
            )

            if is_key_down:
                self._pressed_modifier_keys.add(
                    normalized_modifier_vk
                )

            elif is_key_up:
                self._pressed_modifier_keys.discard(
                    normalized_modifier_vk
                )

            # 只要某个修饰键被任意快捷键映射使用，
            # 就全局吞掉这个修饰键。
            #
            # 例如注册了 shift+q：
            # - 程序内部仍能检测物理 Shift
            # - 前台程序收不到物理 Shift
            # - 自动输入的 qqqrd 不会变成大写
            if modifier_name in self._used_modifiers:
                return 1

            return self._call_next_hook(
                n_code,
                w_param,
                l_param,
            )

        # ----------------------------------------------------
        # 处理已经触发但尚未松开的触发键
        # ----------------------------------------------------

        if vk_code in self._consumed_keys:
            if is_key_up:
                self._consumed_keys.discard(vk_code)

            # 吞掉：
            # 1. 按住触发键产生的自动重复
            # 2. 触发键对应的松开事件
            return 1

        # ----------------------------------------------------
        # 检查新的一次按键
        # ----------------------------------------------------

        if is_key_down:
            active_modifiers = (
                self._get_active_modifiers()
            )

            mapping_key = (
                frozenset(active_modifiers),
                vk_code,
            )

            binding = self._mappings.get(mapping_key)

            if binding is not None:
                output, interval = binding

                self._consumed_keys.add(vk_code)

                self._action_queue.put(
                    (output, interval)
                )

                return 1

        return self._call_next_hook(
            n_code,
            w_param,
            l_param,
        )

    # ========================================================
    # 钩子安装和消息循环
    # ========================================================

    def _install_hook(self):
        module_handle = kernel32.GetModuleHandleW(
            None
        )

        self._hook_handle = (
            user32.SetWindowsHookExW(
                WH_KEYBOARD_LL,
                self._keyboard_callback,
                module_handle,
                0,
            )
        )

        if not self._hook_handle:
            error_code = ctypes.get_last_error()
            raise ctypes.WinError(error_code)

    @staticmethod
    def _message_loop():
        message = wintypes.MSG()

        while True:
            result = user32.GetMessageW(
                ctypes.byref(message),
                None,
                0,
                0,
            )

            if result == 0:
                break

            if result == -1:
                raise ctypes.WinError(
                    ctypes.get_last_error()
                )

            user32.TranslateMessage(
                ctypes.byref(message)
            )

            user32.DispatchMessageW(
                ctypes.byref(message)
            )

    # ========================================================
    # 停止和清理
    # ========================================================

    def _signal_stop_handler(
        self,
        signum,
        frame,
    ):
        self.stop()

    def _cleanup(self):
        if self._hook_handle:
            user32.UnhookWindowsHookEx(
                self._hook_handle
            )

            self._hook_handle = None

        if self._worker_thread is not None:
            self._action_queue.put(None)
            self._worker_thread.join(timeout=1)
            self._worker_thread = None

        self._pressed_modifier_keys.clear()
        self._consumed_keys.clear()

        self._message_thread_id = None
        self._running = False

        self._stopped_event.set()

        print("全局快捷键监听已停止")

    # ========================================================
    # 辅助方法
    # ========================================================

    @staticmethod
    def _validate_input_structure():
        pointer_size = ctypes.sizeof(
            ctypes.c_void_p
        )

        actual_size = ctypes.sizeof(INPUT)

        expected_size = (
            40 if pointer_size == 8 else 28
        )

        if actual_size != expected_size:
            raise RuntimeError(
                f"INPUT 结构大小错误："
                f"当前 {actual_size}，"
                f"预期 {expected_size}"
            )

    def _print_mappings(self):
        print()
        print("全局快捷键已启用：")

        sorted_mappings = sorted(
            self._mappings.items(),
            key=lambda item: (
                sorted(item[0][0]),
                item[0][1],
            ),
        )

        for (
                modifiers,
                vk_code,
        ), binding in sorted_mappings:
            output, interval = binding
            sorted_modifiers = sorted(
                modifiers,
                key=lambda name: MODIFIER_ORDER[name],
            )

            hotkey_text = "+".join(
                [
                    *sorted_modifiers,
                    vk_to_name(vk_code),
                ]
            )

            print(
                f"  {hotkey_text} -> {output!r} "
                f"(间隔 {interval * 1000:g} ms)"
            )

        print()
        print(
            "被映射使用的修饰键会被全局拦截："
            f"{', '.join(sorted(self._used_modifiers))}"
        )
        print("按 Ctrl+C 请求退出")
        print()


# ============================================================
# 默认全局管理器
# ============================================================

_default_manager = GlobalHotkeys()


def bind(hotkey, output, interval=0.05):
    """
    interval：字符间隔，单位为秒。
    """

    _default_manager.bind(
        hotkey,
        output,
        interval=interval,
    )

    return _default_manager


def unregister(hotkey):
    """
    删除映射。
    """

    return _default_manager.unregister(hotkey)


def clear():
    """
    清空全部映射。
    """

    return _default_manager.clear()


def run():
    """
    启动默认管理器。
    """

    _default_manager.run()


def stop():
    """
    请求停止默认管理器。
    """

    _default_manager.stop()

def start(timeout=5.0):
    """
    在后台线程启动默认快捷键管理器。
    """

    return _default_manager.start(timeout=timeout)


def wait(timeout=None):
    """
    等待默认快捷键管理器停止。
    """

    return _default_manager.wait(timeout=timeout)


def join(timeout=None):
    """
    等待默认快捷键后台线程结束。
    """

    return _default_manager.join(timeout=timeout)