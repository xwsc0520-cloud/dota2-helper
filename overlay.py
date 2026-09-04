import sys
import threading
from typing import Dict, List, Optional

from PySide6.QtCore import QObject, Qt, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QApplication, QWidget



# 整体缩放比例。
OVERLAY_SCALE = 2

# 悬浮窗距离屏幕顶部的距离，单位：像素。
OVERLAY_TOP_OFFSET = 70

# 水平方向偏移，单位：像素。
OVERLAY_HORIZONTAL_OFFSET = 0

# 垂直方向额外偏移，单位：像素。
OVERLAY_VERTICAL_OFFSET = 0

# 背景透明度，范围 0~255，数值越小越透明。
OVERLAY_BACKGROUND_ALPHA = 32

# 边框透明度，范围 0~255。
OVERLAY_BORDER_ALPHA = 32

# 文字透明度，范围 0~255。
OVERLAY_TEXT_ALPHA = 196

# 基础尺寸
BASE_OVERLAY_WIDTH = 255
BASE_OVERLAY_HEIGHT = 80


class OverlayController(QObject):
    update_timeline_signal = Signal(
        str,
        object,
        object,
        bool,
    )

    close_signal = Signal()

    def __init__(self):
        super().__init__()

        self.app: Optional[QApplication] = None
        self.window: Optional["TimelineOverlayWindow"] = None
        self.thread: Optional[threading.Thread] = None

        self._started = threading.Event()

    def start(self) -> None:
        if self.thread and self.thread.is_alive():
            return

        self.thread = threading.Thread(
            target=self._run,
            name="DotaOverlay",
            daemon=True,
        )

        self.thread.start()

        if not self._started.wait(timeout=5):
            raise RuntimeError("悬浮窗启动失败")

    def _run(self) -> None:
        self.app = QApplication.instance()

        if self.app is None:
            self.app = QApplication(sys.argv)

        self.window = TimelineOverlayWindow()

        self.update_timeline_signal.connect(
            self.window.set_timeline,
            Qt.ConnectionType.QueuedConnection,
        )

        self.close_signal.connect(
            self.window.close,
            Qt.ConnectionType.QueuedConnection,
        )

        self.window.show()
        self.window.raise_()

        self._started.set()
        self.app.exec()

    def update_timeline(
        self,
        game_time_text: str,
        past_events: List[Dict],
        future_events: List[Dict],
        in_progress: bool,
    ) -> None:
        self.start()

        self.update_timeline_signal.emit(
            game_time_text,
            past_events,
            future_events,
            in_progress,
        )

    def close(self) -> None:
        if self.app is not None:
            self.close_signal.emit()


class TimelineOverlayWindow(QWidget):
    def __init__(self):
        super().__init__()

        self.game_time_text = "--:--"
        self.past_events: List[Dict] = []
        self.future_events: List[Dict] = []
        self.in_progress = False

        self.setWindowTitle("Dota 2 时间轴悬浮提示")

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )

        self.setAttribute(
            Qt.WidgetAttribute.WA_TranslucentBackground,
            True,
        )

        self.setAttribute(
            Qt.WidgetAttribute.WA_TransparentForMouseEvents,
            True,
        )

        self._apply_scaled_size()
        self._move_to_position()

        if sys.platform.startswith("win"):
            self._set_windows_click_through_topmost()

    @property
    def scale(self) -> float:
        """
        返回有效缩放比例，避免配置错误导致窗口尺寸异常。
        """
        return max(0.1, float(OVERLAY_SCALE))

    def _scaled(self, value: float) -> int:
        """
        根据全局缩放比例换算尺寸。
        """
        return max(1, round(value * self.scale))

    def _apply_scaled_size(self) -> None:
        """
        根据 OVERLAY_SCALE 设置窗口尺寸。
        """
        self.resize(
            self._scaled(BASE_OVERLAY_WIDTH),
            self._scaled(BASE_OVERLAY_HEIGHT),
        )

    def _move_to_position(self) -> None:
        """
        根据全局位置参数设置悬浮窗位置。
        """
        screen = self.screen()

        if screen is None:
            return

        geometry = screen.availableGeometry()

        x = (
            geometry.left()
            + (
                geometry.width()
                - self.width()
            ) // 2
            + OVERLAY_HORIZONTAL_OFFSET
        )

        y = (
            geometry.top()
            + OVERLAY_TOP_OFFSET
            + OVERLAY_VERTICAL_OFFSET
        )

        self.move(x, y)

    def _set_windows_click_through_topmost(self) -> None:
        try:
            import ctypes

            hwnd = int(self.winId())
            user32 = ctypes.windll.user32

            GWL_EXSTYLE = -20

            WS_EX_TRANSPARENT = 0x00000020
            WS_EX_LAYERED = 0x00080000
            WS_EX_NOACTIVATE = 0x08000000
            WS_EX_TOOLWINDOW = 0x00000080

            current_style = user32.GetWindowLongW(
                hwnd,
                GWL_EXSTYLE,
            )

            user32.SetWindowLongW(
                hwnd,
                GWL_EXSTYLE,
                current_style
                | WS_EX_TRANSPARENT
                | WS_EX_LAYERED
                | WS_EX_NOACTIVATE
                | WS_EX_TOOLWINDOW,
            )

            HWND_TOPMOST = -1

            SWP_NOSIZE = 0x0001
            SWP_NOMOVE = 0x0002
            SWP_NOACTIVATE = 0x0010
            SWP_SHOWWINDOW = 0x0040

            user32.SetWindowPos(
                hwnd,
                HWND_TOPMOST,
                0,
                0,
                0,
                0,
                SWP_NOSIZE
                | SWP_NOMOVE
                | SWP_NOACTIVATE
                | SWP_SHOWWINDOW,
            )

        except Exception as exc:
            print(
                f"[悬浮窗] Windows 置顶设置失败：{exc}",
                flush=True,
            )

    def set_timeline(
        self,
        game_time_text: str,
        past_events: List[Dict],
        future_events: List[Dict],
        in_progress: bool,
    ) -> None:
        self.game_time_text = game_time_text
        self.past_events = list(past_events or [])
        self.future_events = list(future_events or [])
        self.in_progress = bool(in_progress)

        self.show()
        self.raise_()

        if sys.platform.startswith("win"):
            self._set_windows_click_through_topmost()

        self.update()

    @staticmethod
    def _event_text(
        event: Optional[Dict],
        empty_text: str,
    ) -> str:
        if not event:
            return empty_text

        trigger_time_text = event.get(
            "trigger_time_text",
            "--:--",
        )

        message = event.get(
            "message",
            "",
        )

        return f"{trigger_time_text}  {message}"

    def paintEvent(self, event) -> None:
        painter = QPainter(self)

        painter.setRenderHint(
            QPainter.RenderHint.Antialiasing
        )

        # 所有绘制尺寸都乘以统一缩放比例
        s = self.scale

        def px(value: float) -> int:
            return max(1, round(value * s))

        panel_rect = self.rect().adjusted(
            px(2),
            px(2),
            -px(2),
            -px(2),
        )

        # 主背景
        painter.setPen(
            QPen(
                QColor(
                    255,
                    255,
                    255,
                    OVERLAY_BORDER_ALPHA,
                ),
                px(1),
            )
        )

        painter.setBrush(
            QColor(
                8,
                15,
                28,
                OVERLAY_BACKGROUND_ALPHA,
            )
        )

        painter.drawRoundedRect(
            panel_rect,
            px(6),
            px(6),
        )

        # 当前游戏时间
        painter.setFont(
            QFont(
                "Microsoft YaHei",
                px(9),
                QFont.Weight.Bold,
            )
        )

        painter.setPen(
            QColor(
                255,
                196,
                42,
                OVERLAY_TEXT_ALPHA,
            )
        )

        painter.drawText(
            px(8),
            px(3),
            px(52),
            px(20),
            Qt.AlignmentFlag.AlignLeft
            | Qt.AlignmentFlag.AlignVCenter,
            self.game_time_text,
        )

        # 状态
        painter.setFont(
            QFont(
                "Microsoft YaHei",
                px(6),
                QFont.Weight.Bold,
            )
        )

        if self.in_progress:
            status_text = "比赛进行中"
            status_color = QColor(
                52,
                211,
                153,
                OVERLAY_TEXT_ALPHA,
            )
        else:
            status_text = "等待比赛 / 已暂停"
            status_color = QColor(
                203,
                213,
                225,
                OVERLAY_TEXT_ALPHA,
            )

        painter.setPen(status_color)

        painter.drawText(
            px(61),
            px(4),
            px(82),
            px(18),
            Qt.AlignmentFlag.AlignLeft
            | Qt.AlignmentFlag.AlignVCenter,
            status_text,
        )

        past = (
            self.past_events[0]
            if self.past_events
            else None
        )

        future_1 = (
            self.future_events[0]
            if len(self.future_events) >= 1
            else None
        )

        future_2 = (
            self.future_events[1]
            if len(self.future_events) >= 2
            else None
        )

        rows = [
            (
                "刚刚",
                self._event_text(
                    past,
                    "暂无已发生事件",
                ),
                QColor(
                    148,
                    163,
                    184,
                    OVERLAY_TEXT_ALPHA,
                ),
            ),
            (
                "接下来",
                self._event_text(
                    future_1,
                    "暂无后续事件",
                ),
                QColor(
                    96,
                    165,
                    250,
                    OVERLAY_TEXT_ALPHA,
                ),
            ),
            (
                "之后",
                self._event_text(
                    future_2,
                    "暂无后续事件",
                ),
                QColor(
                    167,
                    139,
                    250,
                    OVERLAY_TEXT_ALPHA,
                ),
            ),
        ]

        start_y = 25
        row_height = 17
        row_width_margin = 6
        row_height_value = 14
        row_radius = 3

        for index, (
            label,
            text,
            color,
        ) in enumerate(rows):
            y = start_y + index * row_height

            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(
                QColor(
                    255,
                    255,
                    255,
                    8,
                )
            )

            painter.drawRoundedRect(
                px(row_width_margin),
                px(y),
                self.width() - px(row_width_margin * 2),
                px(row_height_value),
                px(row_radius),
                px(row_radius),
            )

            # 标签
            painter.setFont(
                QFont(
                    "Microsoft YaHei",
                    px(6),
                    QFont.Weight.Bold,
                )
            )

            painter.setPen(color)

            painter.drawText(
                px(6),
                px(y),
                px(38),
                px(row_height_value),
                Qt.AlignmentFlag.AlignLeft
                | Qt.AlignmentFlag.AlignVCenter,
                label,
            )

            # 事件文字
            painter.setFont(
                QFont(
                    "Microsoft YaHei",
                    px(6),
                    QFont.Weight.Bold,
                )
            )

            painter.setPen(
                QColor(
                    248,
                    250,
                    252,
                    OVERLAY_TEXT_ALPHA,
                )
            )

            painter.drawText(
                px(43),
                px(y),
                self.width() - px(49),
                px(row_height_value),
                Qt.AlignmentFlag.AlignLeft
                | Qt.AlignmentFlag.AlignVCenter,
                text,
            )
