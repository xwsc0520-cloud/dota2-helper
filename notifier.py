import queue
import sys
import threading
import time
from typing import Optional


class ChineseVoiceNotifier:
    """
    中文语音播报器。

    特点：
    1. 不显示桌面通知；
    2. 只播放语音；
    3. 每条语音独立初始化 TTS 引擎；
    4. 前一条失败不会影响后续语音；
    5. 使用队列保证播报顺序。
    """

    def __init__(
        self,
        enabled: bool = True,
        rate: int = 185,
        volume: float = 1.0,
        duplicate_interval: float = 0.8,
    ):
        self.enabled = enabled
        self.rate = rate
        self.volume = max(
            0.0,
            min(1.0, volume),
        )
        self.duplicate_interval = duplicate_interval

        self._queue: queue.Queue[
            Optional[str]
        ] = queue.Queue()

        self._thread: Optional[
            threading.Thread
        ] = None

        self._started = False
        self._start_lock = threading.Lock()

        self._last_text = ""
        self._last_time = 0.0

    def start(self) -> None:
        with self._start_lock:
            if self._started:
                return

            self._thread = threading.Thread(
                target=self._worker,
                name="ChineseVoiceNotifier",
                daemon=True,
            )

            self._thread.start()
            self._started = True

    def speak(self, text: str) -> None:
        if not self.enabled:
            return

        text = str(text).strip()

        if not text:
            return

        now = time.monotonic()

        # 防止同一事件因为 GSI 重复推送而重复播报。
        if (
            text == self._last_text
            and now - self._last_time
            < self.duplicate_interval
        ):
            return

        self._last_text = text
        self._last_time = now

        self.start()
        self._queue.put(text)

        print(
            f"[语音队列] 已加入：{text}",
            flush=True,
        )

    def close(self) -> None:
        if self._started:
            self._queue.put(None)

    def _worker(self) -> None:
        while True:
            text = self._queue.get()

            try:
                if text is None:
                    return

                self._speak_once(text)

            except Exception as exc:
                # 一条语音失败时，不退出工作线程。
                print(
                    f"[语音线程] 本条播报失败：{exc}",
                    file=sys.stderr,
                    flush=True,
                )

            finally:
                self._queue.task_done()

    def _speak_once(self, text: str) -> None:
        print(
            f"[语音开始] {text}",
            flush=True,
        )

        try:
            import pyttsx3
        except ImportError:
            print(
                "[语音错误] 未安装 pyttsx3，请执行：",
                file=sys.stderr,
                flush=True,
            )
            print(
                ".venv\\Scripts\\python.exe "
                "-m pip install pyttsx3",
                file=sys.stderr,
                flush=True,
            )
            return

        engine = None

        try:
            # 每条语音重新初始化，避免 Windows SAPI 状态卡死。
            engine = pyttsx3.init()

            engine.setProperty(
                "rate",
                self.rate,
            )

            engine.setProperty(
                "volume",
                self.volume,
            )

            voice_id = self._select_chinese_voice(
                engine
            )

            if voice_id:
                engine.setProperty(
                    "voice",
                    voice_id,
                )
            else:
                print(
                    "[语音警告] 未找到中文语音，"
                    "使用系统默认语音。",
                    flush=True,
                )

            engine.say(text)
            engine.runAndWait()

            print(
                f"[语音完成] {text}",
                flush=True,
            )

        except Exception as exc:
            print(
                f"[语音错误] {exc}",
                file=sys.stderr,
                flush=True,
            )

        finally:
            if engine is not None:
                try:
                    engine.stop()
                except Exception:
                    pass

            # 给 Windows SAPI 一点释放时间。
            time.sleep(0.12)

    @staticmethod
    def _select_chinese_voice(
        engine,
    ) -> Optional[str]:
        try:
            voices = engine.getProperty(
                "voices"
            )
        except Exception as exc:
            print(
                f"[语音] 获取语音列表失败：{exc}",
                flush=True,
            )
            return None

        keywords = (
            "zh-cn",
            "zh_cn",
            "zh-hans",
            "chinese",
            "mandarin",
            "huihui",
            "xiaoxiao",
            "yaoyao",
            "yunxi",
            "中文",
            "普通话",
        )

        for voice in voices:
            values = [
                str(
                    getattr(
                        voice,
                        "id",
                        "",
                    )
                ),
                str(
                    getattr(
                        voice,
                        "name",
                        "",
                    )
                ),
            ]

            languages = getattr(
                voice,
                "languages",
                [],
            )

            for language in languages:
                if isinstance(
                    language,
                    bytes,
                ):
                    language = language.decode(
                        "utf-8",
                        errors="ignore",
                    )

                values.append(str(language))

            text = " ".join(values).lower()

            if any(
                keyword in text
                for keyword in keywords
            ):
                print(
                    f"[语音] 选择语音：{values}",
                    flush=True,
                )
                return str(
                    getattr(
                        voice,
                        "id",
                        "",
                    )
                )

        return None


if __name__ == "__main__":
    print("开始测试中文语音……")

    notifier = ChineseVoiceNotifier()

    notifier.speak(
        "提示系统工作正常"
    )

    notifier.speak(
        "二十秒后莲花刷新"
    )

    notifier.speak(
        "莲花已经刷新"
    )

    notifier.speak(
        "二十秒后智慧符刷新"
    )

    # 主线程等待队列处理完成。
    notifier._queue.join()

    print("语音测试结束")
