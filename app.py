import json
import threading
from collections import deque
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from flask import Flask, jsonify, request

from notifier import ChineseVoiceNotifier
from overlay import OverlayController
from rule_engine import (
    Rule,
    RuleEngine,
    TimelineEvent,
    format_game_time,
    get_game_time,
    is_game_in_progress,
)


BASE_DIR = Path(__file__).resolve().parent
RULES_FILE = BASE_DIR / "rules.json"

app = Flask(__name__)

state_lock = threading.RLock()

latest_state: Dict[str, Any] = {}
recent_events = deque(maxlen=50)


def load_rules() -> List[Rule]:
    with RULES_FILE.open(
        "r",
        encoding="utf-8",
    ) as file:
        values = json.load(file)

    if not isinstance(values, list):
        raise ValueError(
            "rules.json 顶层必须是数组"
        )

    return [
        Rule.from_dict(value)
        for value in values
    ]


engine = RuleEngine(load_rules())

voice = ChineseVoiceNotifier(
    enabled=True,
    rate=190,
    volume=1.0,
)

overlay = OverlayController()
overlay.start()


def timeline_event_to_dict(
    event: TimelineEvent,
) -> Dict[str, Any]:
    return {
        "rule_id": event.rule_id,
        "name": event.name,
        "message": event.message,
        "trigger_time": event.trigger_time,
        "trigger_time_text": format_game_time(
            event.trigger_time
        ),
        "target_time": event.target_time,
        "target_time_text": format_game_time(
            event.target_time
        ),
    }


def update_overlay(
    game_time: int,
    in_progress: bool,
) -> None:
    past, future = engine.timeline(
        game_time=game_time,
        past_count=1,
        future_count=2,
    )

    overlay.update_timeline(
        game_time_text=format_game_time(
            game_time
        ),
        past_events=[
            timeline_event_to_dict(event)
            for event in past
        ],
        future_events=[
            timeline_event_to_dict(event)
            for event in future
        ],
        in_progress=in_progress,
    )


def reset_match_locked() -> None:
    global latest_state

    latest_state = {}
    recent_events.clear()
    engine.reset()


@app.post("/gsi")
def receive_gsi():
    global latest_state

    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify(
            {
                "ok": False,
                "error": "请求体必须是 JSON 对象",
            }
        ), 400

    triggered_events = []

    with state_lock:
        latest_state = data

        game_time = get_game_time(data)
        in_progress = is_game_in_progress(data)

        if game_time is not None:
            if in_progress:
                triggered_events = engine.update(
                    game_time
                )

                for event in triggered_events:
                    recent_events.appendleft(
                        {
                            "rule_id": event.rule_id,
                            "name": event.name,
                            "message": event.message,
                            "trigger_time":
                                event.trigger_time,
                            "trigger_time_text":
                                format_game_time(
                                    event.trigger_time
                                ),
                            "target_time":
                                event.target_time,
                            "target_time_text":
                                format_game_time(
                                    event.target_time
                                ),
                            "received_at":
                                datetime.now().isoformat(
                                    timespec="seconds"
                                ),
                        }
                    )

            update_overlay(
                game_time=game_time,
                in_progress=in_progress,
            )

    # 锁外播报，避免 TTS 影响 GSI 请求。
    for event in triggered_events:
        voice.speak(event.message)

    return jsonify(
        {
            "ok": True,
            "game_time": get_game_time(data),
            "events_triggered": len(
                triggered_events
            ),
        }
    )


@app.get("/api/state")
def api_state():
    with state_lock:
        game_time = get_game_time(
            latest_state
        )

        if game_time is None:
            past = []
            future = []
        else:
            past_events, future_events = (
                engine.timeline(
                    game_time,
                    past_count=1,
                    future_count=2,
                )
            )

            past = [
                timeline_event_to_dict(event)
                for event in past_events
            ]

            future = [
                timeline_event_to_dict(event)
                for event in future_events
            ]

        return jsonify(
            {
                "connected": bool(latest_state),
                "game_time": game_time,
                "game_time_text":
                    format_game_time(game_time),
                "in_progress":
                    is_game_in_progress(
                        latest_state
                    ),
                "past": past,
                "future": future,
                "events": list(recent_events),
                "state": latest_state,
            }
        )


@app.post("/api/reset")
def api_reset():
    with state_lock:
        reset_match_locked()

    overlay.update_timeline(
        game_time_text="--:--",
        past_events=[],
        future_events=[],
        in_progress=False,
    )

    return jsonify({"ok": True})


@app.get("/health")
def health():
    return jsonify({"ok": True})


@app.get("/")
def index():
    return """
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>Dota 2 提示工具</title>
</head>
<body>
  <h1>Dota 2 提示工具正在运行</h1>
  <p>常驻时间轴悬浮窗已启动。</p>
  <p>事件发生时使用中文语音播报。</p>
  <p>
    <a href="/api/state">
      查看当前状态 JSON
    </a>
  </p>
</body>
</html>
"""


if __name__ == "__main__":
    print("Dota 2 提示工具已启动")
    print("GSI：http://127.0.0.1:3000/gsi")
    print("状态：http://127.0.0.1:3000")
    print("提示方式：常驻悬浮时间轴 + 中文语音")
    print("按 Ctrl+C 停止")

    app.run(
        host="127.0.0.1",
        port=3000,
        debug=False,
        threaded=True,
        use_reloader=False,
    )
