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
        future_count=5,
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


def get_last_hits_ranking_text(
    state: Dict[str, Any],
) -> str:
    player_data = state.get("player")

    if not isinstance(player_data, dict):
        return ""

    players = []

    for player_key, player in player_data.items():
        if not isinstance(player, dict):
            continue

        # 只处理包含 last_hits 的玩家对象
        if "last_hits" not in player:
            continue

        try:
            last_hits = int(
                player.get("last_hits", 0)
            )
        except (TypeError, ValueError):
            last_hits = 0

        name = player.get("name")

        if not isinstance(name, str) or not name:
            name = player_key

        players.append(
            {
                "name": name,
                "last_hits": last_hits,
            }
        )

    players.sort(
        key=lambda player: player["last_hits"],
        reverse=True,
    )

    return "\n".join(
        f"{index}. {player['name']}："
        f"{player['last_hits']} 补刀"
        for index, player in enumerate(
            players,
            start=1,
        )
    )


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
        last_hits_ranking_text = get_last_hits_ranking_text(data)

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

        overlay.update_last_hits_ranking(
            last_hits_ranking_text
        )

    # 锁外播报，避免 TTS 影响 GSI 请求。
    for event in triggered_events:
        voice.speak(event.message)

    return "", 200


if __name__ == "__main__":
    print("Dota 2 提示工具已启动")

    app.run(
        host="127.0.0.1",
        port=3000,
        debug=False,
        threaded=True,
        use_reloader=False,
    )
