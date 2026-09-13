import json
import threading
from collections import deque
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from flask import Flask, request

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

recent_events = deque(maxlen=50)

game_time_last = 0
gold_total = 0
gold_last = 0


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

import global_hotkeys

global_hotkeys.bind('alt+q', 'qqqrd')
global_hotkeys.bind('alt+w', 'qwwrd')
global_hotkeys.bind('alt+e', 'qqerd')
global_hotkeys.bind('alt+r', 'qwerd')

global_hotkeys.bind('alt+a', 'eeerd')
global_hotkeys.bind('alt+s', 'weerd')
global_hotkeys.bind('alt+d', 'wwwrd')

global_hotkeys.bind('alt+z', 'qqwrd')
global_hotkeys.bind('alt+x', 'wwerd')
global_hotkeys.bind('alt+c', 'qeerd')


global_hotkeys.bind('shift+q', 'qqqr')
global_hotkeys.bind('shift+w', 'qwwr')
global_hotkeys.bind('shift+e', 'qqer')
global_hotkeys.bind('shift+r', 'qwer')

global_hotkeys.bind('shift+a', 'eeer')
global_hotkeys.bind('shift+s', 'weer')
global_hotkeys.bind('shift+d', 'wwwr')

global_hotkeys.bind('shift+z', 'qqwr')
global_hotkeys.bind('shift+x', 'wwer')
global_hotkeys.bind('shift+c', 'qeer')

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


@app.post("/gsi")
def receive_gsi():
    data: dict = request.get_json(silent=True)
    triggered_events = []

    with state_lock:
        global game_time_last, gold_total, gold_last

        game_time: int = get_game_time(data)
        in_progress = is_game_in_progress(data)
        if game_time < game_time_last:
            gold_total = 0
            gold_last = 0
        game_time_last = game_time

        info = ''
        gpm = data['player']['gpm']
        gold = data['player']['gold']
        if gold > gold_last:
            gold_total += gold - gold_last
        gold_last = gold

        info += f'gpm:{gpm}\n'
        info += f'gold:{gold_total}\n'

        overlay.update_info(info)

        hero_name = data['hero']['name']
        if hero_name == 'npc_dota_hero_invoker':
            global_hotkeys.start()
        else:
            global_hotkeys.stop()
            global_hotkeys.join()

        if in_progress:
            triggered_events = engine.update(game_time)

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
