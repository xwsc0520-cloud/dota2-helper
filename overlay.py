import sys
import threading
from typing import Dict, List, Optional

from PySide6.QtCore import QObject, QRect, Qt, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QApplication, QWidget



# 整体缩放比例。
OVERLAY_SCALE = 1.5

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

BASE_TIMELINE_WIDTH = 255
BASE_LAST_HITS_WIDTH = 180
BASE_PANEL_GAP = 8

BASE_OVERLAY_WIDTH = (
    BASE_TIMELINE_WIDTH
    + BASE_PANEL_GAP
    + BASE_LAST_HITS_WIDTH
)

BASE_OVERLAY_HEIGHT = 132


class OverlayController(QObject):
    update_timeline_signal = Signal(
        str,
        object,
        object,
        bool,
    )

    update_last_hits_signal = Signal(str)

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

        self.update_last_hits_signal.connect(
            self.window.set_last_hits_ranking,
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

    def update_last_hits_ranking(
            self,
            text: str,
    ) -> None:
        self.start()

        self.update_last_hits_signal.emit(
            text or ""
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

        self.last_hits_ranking_text = ""

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

    def _draw_last_hits_panel(
            self,
            painter: QPainter,
            px,
    ) -> None:
        """
        绘制右侧补刀排序区域。
        """

        panel_x = (
                BASE_TIMELINE_WIDTH
                + BASE_PANEL_GAP
        )

        panel_width = BASE_LAST_HITS_WIDTH
        panel_height = BASE_OVERLAY_HEIGHT

        # 右侧背景
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
            px(panel_x + 2),
            px(2),
            px(panel_width - 4),
            px(panel_height - 4),
            px(6),
            px(6),
        )

        # 标题
        painter.setFont(
            QFont(
                "Microsoft YaHei",
                px(7),
                QFont.Weight.Bold,
            )
        )

        painter.setPen(
            QColor(
                251,
                191,
                36,
                OVERLAY_TEXT_ALPHA,
            )
        )

        painter.drawText(
            px(panel_x + 8),
            px(6),
            px(panel_width - 16),
            px(18),
            Qt.AlignmentFlag.AlignLeft
            | Qt.AlignmentFlag.AlignVCenter,
            "补刀排行",
        )

        ranking_text = (
            self.last_hits_ranking_text.strip()
        )

        if not ranking_text:
            ranking_text = "暂无数据"

        lines = ranking_text.splitlines()

        # 最多显示 10 行玩家
        lines = lines[:10]

        painter.setFont(
            QFont(
                "Microsoft YaHei",
                px(6),
                QFont.Weight.Bold,
            )
        )

        line_height = 10
        start_y = 27

        for index, line in enumerate(lines):
            y = start_y + index * line_height

            # 每行背景
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
                px(panel_x + 6),
                px(y),
                px(panel_width - 16),
                px(9),
                px(2),
                px(2),
            )

            # 每行文字
            painter.setPen(
                QColor(
                    248,
                    250,
                    252,
                    OVERLAY_TEXT_ALPHA,
                )
            )

            painter.drawText(
                px(panel_x + 9),
                px(y),
                px(panel_width - 22),
                px(9),
                Qt.AlignmentFlag.AlignLeft
                | Qt.AlignmentFlag.AlignVCenter,
                line,
            )

    def set_last_hits_ranking(
            self,
            text: str,
    ) -> None:
        self.last_hits_ranking_text = text or ""

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

        timeline_panel_rect = QRect(
            px(2),
            px(2),
            px(BASE_TIMELINE_WIDTH - 4),
            px(BASE_OVERLAY_HEIGHT - 4),
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
            timeline_panel_rect,
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
                self._scaled(BASE_TIMELINE_WIDTH - row_width_margin * 2),
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
                self._scaled(BASE_TIMELINE_WIDTH - 49),
                px(row_height_value),
                Qt.AlignmentFlag.AlignLeft
                | Qt.AlignmentFlag.AlignVCenter,
                text,
            )

        self._draw_last_hits_panel(
            painter,
            px,
        )

