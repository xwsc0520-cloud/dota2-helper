import argparse
import json
import sys
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict
from urllib.parse import urlparse

import requests


HTML = r"""
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Dota 2 GSI 模拟器</title>

  <style>
    body {
      margin: 0;
      background: #0f172a;
      color: #e2e8f0;
      font-family: Arial, "Microsoft YaHei", sans-serif;
    }

    main {
      max-width: 760px;
      margin: 40px auto;
      padding: 0 20px;
    }

    section {
      background: #1e293b;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 18px;
    }

    #game-time {
      color: #fbbf24;
      font-size: 64px;
      font-weight: bold;
    }

    button,
    input {
      box-sizing: border-box;
      font-size: 16px;
      margin: 5px;
      padding: 10px;
    }

    button {
      border: 0;
      border-radius: 7px;
      background: #2563eb;
      color: white;
      cursor: pointer;
    }

    button:hover {
      filter: brightness(1.1);
    }

    button:disabled {
      cursor: not-allowed;
      opacity: 0.55;
    }

    button.danger {
      background: #dc2626;
    }

    button.green {
      background: #059669;
    }

    input {
      border: 1px solid #64748b;
      border-radius: 7px;
      width: 120px;
    }

    .ok {
      color: #34d399;
    }

    .bad {
      color: #f87171;
    }

    .info {
      color: #60a5fa;
    }

    #operation-result {
      min-height: 24px;
      margin-top: 12px;
    }

    pre {
      background: #0f172a;
      padding: 12px;
      border-radius: 8px;
      overflow: auto;
    }
  </style>
</head>

<body>
  <main>
    <h1>Dota 2 GSI 模拟器</h1>

    <section>
      <div id="game-time">0:00</div>
      <div id="running-status">正在加载状态……</div>
      <div id="send-status"></div>
    </section>

    <section>
      <button id="start-button" class="green" type="button">
        开始
      </button>

      <button id="pause-button" type="button">
        暂停
      </button>

      <button id="resume-button" type="button">
        继续
      </button>

      <button id="reset-button" class="danger" type="button">
        重置为 0:00
      </button>

      <div id="operation-result"></div>
    </section>

    <section>
      <label for="set-time-input">
        设置游戏时间（秒）：
      </label>

      <input
        id="set-time-input"
        type="number"
        step="1"
        value="150"
      >

      <button id="set-time-button" type="button">
        设置
      </button>

      <p>
        设为 150 秒后，继续运行约 10 个游戏秒，
        即可测试莲花提前提醒。
      </p>
    </section>

    <section>
      <label for="speed-input">
        模拟速度：
      </label>

      <input
        id="speed-input"
        type="number"
        min="0.1"
        step="0.1"
        value="10"
      >

      <button id="set-speed-button" type="button">
        更新速度
      </button>
    </section>

    <section>
      <h2>说明</h2>

      <ul>
        <li>默认 10 倍速度。</li>
        <li>0:10 触发测试提醒。</li>
        <li>2:40 触发“20 秒后莲花刷新”。</li>
        <li>3:00 触发“莲花已刷新”。</li>
      </ul>

      <pre id="raw-state">{}</pre>
    </section>
  </main>

  <script>
    (() => {
      "use strict";

      const elements = {
        gameTime: document.getElementById("game-time"),
        runningStatus: document.getElementById("running-status"),
        sendStatus: document.getElementById("send-status"),
        operationResult: document.getElementById("operation-result"),
        rawState: document.getElementById("raw-state"),

        startButton: document.getElementById("start-button"),
        pauseButton: document.getElementById("pause-button"),
        resumeButton: document.getElementById("resume-button"),
        resetButton: document.getElementById("reset-button"),

        setTimeInput: document.getElementById("set-time-input"),
        setTimeButton: document.getElementById("set-time-button"),

        speedInput: document.getElementById("speed-input"),
        setSpeedButton: document.getElementById("set-speed-button")
      };

      let requestInProgress = false;

      function setOperationMessage(message, type = "info") {
        elements.operationResult.className = type;
        elements.operationResult.textContent = message;
      }

      function setButtonsDisabled(disabled) {
        elements.startButton.disabled = disabled;
        elements.pauseButton.disabled = disabled;
        elements.resumeButton.disabled = disabled;
        elements.resetButton.disabled = disabled;
        elements.setTimeButton.disabled = disabled;
        elements.setSpeedButton.disabled = disabled;
      }

      async function requestJson(path, options = {}) {
        const response = await fetch(path, {
          cache: "no-store",
          ...options
        });

        const text = await response.text();

        let data;

        try {
          data = text ? JSON.parse(text) : {};
        } catch (error) {
          throw new Error(
            `服务器返回了无效 JSON：${text}`
          );
        }

        if (!response.ok) {
          throw new Error(
            data.error ||
            `请求失败，HTTP 状态码：${response.status}`
          );
        }

        return data;
      }

      async function refreshState() {
        try {
          const data = await requestJson("/api/state");

          elements.gameTime.textContent =
            data.game_time_text || "0:00";

          elements.runningStatus.textContent =
            data.running ? "比赛进行中" : "已暂停";

          elements.runningStatus.className =
            data.running ? "ok" : "";

          if (data.last_send_ok) {
            elements.sendStatus.className = "ok";
            elements.sendStatus.textContent =
              "最近一次 GSI 发送成功";
          } else {
            elements.sendStatus.className = "bad";
            elements.sendStatus.textContent =
              "尚未成功发送：" +
              (data.last_error || "等待发送");
          }

          if (
            document.activeElement !== elements.speedInput &&
            data.speed !== undefined
          ) {
            elements.speedInput.value = data.speed;
          }

          elements.rawState.textContent =
            JSON.stringify(data, null, 2);
        } catch (error) {
          elements.sendStatus.className = "bad";
          elements.sendStatus.textContent =
            `读取模拟器状态失败：${error.message}`;
        }
      }

      async function executeControl(action, successMessage) {
        if (requestInProgress) {
          return;
        }

        requestInProgress = true;
        setButtonsDisabled(true);
        setOperationMessage("正在执行……", "info");

        try {
          const result = await requestJson(
            `/api/${action}`,
            {
              method: "POST"
            }
          );

          console.log(`操作 ${action} 执行成功：`, result);
          setOperationMessage(successMessage, "ok");

          await refreshState();
        } catch (error) {
          console.error(`操作 ${action} 执行失败：`, error);
          setOperationMessage(
            `操作失败：${error.message}`,
            "bad"
          );
        } finally {
          requestInProgress = false;
          setButtonsDisabled(false);
        }
      }

      async function setGameTime() {
        const value = Number(elements.setTimeInput.value);

        if (!Number.isFinite(value)) {
          setOperationMessage(
            "游戏时间必须是有效数字",
            "bad"
          );
          return;
        }

        requestInProgress = true;
        setButtonsDisabled(true);

        try {
          const result = await requestJson(
            "/api/time",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                game_time: value
              })
            }
          );

          console.log("设置游戏时间成功：", result);
          setOperationMessage(
            `游戏时间已设置为 ${value} 秒`,
            "ok"
          );

          await refreshState();
        } catch (error) {
          console.error("设置游戏时间失败：", error);
          setOperationMessage(
            `设置游戏时间失败：${error.message}`,
            "bad"
          );
        } finally {
          requestInProgress = false;
          setButtonsDisabled(false);
        }
      }

      async function setSimulationSpeed() {
        const value = Number(elements.speedInput.value);

        if (!Number.isFinite(value) || value <= 0) {
          setOperationMessage(
            "模拟速度必须是大于 0 的数字",
            "bad"
          );
          return;
        }

        requestInProgress = true;
        setButtonsDisabled(true);

        try {
          const result = await requestJson(
            "/api/speed",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                speed: value
              })
            }
          );

          console.log("更新速度成功：", result);
          setOperationMessage(
            `模拟速度已更新为 ${value} 倍`,
            "ok"
          );

          await refreshState();
        } catch (error) {
          console.error("更新速度失败：", error);
          setOperationMessage(
            `更新速度失败：${error.message}`,
            "bad"
          );
        } finally {
          requestInProgress = false;
          setButtonsDisabled(false);
        }
      }

      elements.startButton.addEventListener(
        "click",
        () => executeControl("start", "模拟比赛已开始")
      );

      elements.pauseButton.addEventListener(
        "click",
        () => executeControl("pause", "模拟比赛已暂停")
      );

      elements.resumeButton.addEventListener(
        "click",
        () => executeControl("resume", "模拟比赛已继续")
      );

      elements.resetButton.addEventListener(
        "click",
        () => executeControl("reset", "模拟比赛已重置")
      );

      elements.setTimeButton.addEventListener(
        "click",
        setGameTime
      );

      elements.setSpeedButton.addEventListener(
        "click",
        setSimulationSpeed
      );

      elements.setTimeInput.addEventListener(
        "keydown",
        event => {
          if (event.key === "Enter") {
            setGameTime();
          }
        }
      );

      elements.speedInput.addEventListener(
        "keydown",
        event => {
          if (event.key === "Enter") {
            setSimulationSpeed();
          }
        }
      );

      refreshState();
      window.setInterval(refreshState, 500);
    })();
  </script>
</body>
</html>
"""



def format_game_time(seconds: int) -> str:
    sign = "-" if seconds < 0 else ""
    seconds = abs(int(seconds))
    minutes, remaining = divmod(seconds, 60)
    return f"{sign}{minutes}:{remaining:02d}"


@dataclass
class SimulatorState:
    target_url: str
    speed: float
    game_time: float = 0.0
    running: bool = False
    last_send_ok: bool = False
    last_error: str = ""
    last_sent_at: str = ""

    players: Dict[str, Dict[str, Any]] = field(
        default_factory=dict
    )

    lock: threading.RLock = field(
        default_factory=threading.RLock
    )

    def snapshot(self) -> Dict[str, Any]:
        with self.lock:
            integer_time = int(self.game_time)

            return {
                "target_url": self.target_url,
                "speed": self.speed,
                "game_time": integer_time,
                "game_time_text":
                    format_game_time(integer_time),
                "running": self.running,
                "last_send_ok": self.last_send_ok,
                "last_error": self.last_error,
                "last_sent_at": self.last_sent_at,
                "players": self.players,
            }

    def make_gsi_payload(
            self,
    ) -> Dict[str, Any]:
        with self.lock:
            game_time = int(self.game_time)
            running = self.running

        # 根据游戏时间模拟补刀数。
        #
        # 每名玩家每 15 秒增加一定数量的补刀。
        # 这里故意设置不同的补刀效率，
        # 以便测试排序结果。
        player_configs = [
            {
                "key": "player0",
                "steamid": "SIMULATED_PLAYER_0",
                "name": "Radiant Carry",
                "team_name": "radiant",
                "last_hits_per_second": 0.32,
            },
            {
                "key": "player1",
                "steamid": "SIMULATED_PLAYER_1",
                "name": "Radiant Mid",
                "team_name": "radiant",
                "last_hits_per_second": 0.28,
            },
            {
                "key": "player2",
                "steamid": "SIMULATED_PLAYER_2",
                "name": "Radiant Offlane",
                "team_name": "radiant",
                "last_hits_per_second": 0.20,
            },
            {
                "key": "player3",
                "steamid": "SIMULATED_PLAYER_3",
                "name": "Radiant Support",
                "team_name": "radiant",
                "last_hits_per_second": 0.12,
            },
            {
                "key": "player4",
                "steamid": "SIMULATED_PLAYER_4",
                "name": "Radiant Hard Support",
                "team_name": "radiant",
                "last_hits_per_second": 0.08,
            },
            {
                "key": "player5",
                "steamid": "SIMULATED_PLAYER_5",
                "name": "Dire Carry",
                "team_name": "dire",
                "last_hits_per_second": 0.30,
            },
            {
                "key": "player6",
                "steamid": "SIMULATED_PLAYER_6",
                "name": "Dire Mid",
                "team_name": "dire",
                "last_hits_per_second": 0.26,
            },
            {
                "key": "player7",
                "steamid": "SIMULATED_PLAYER_7",
                "name": "Dire Offlane",
                "team_name": "dire",
                "last_hits_per_second": 0.21,
            },
            {
                "key": "player8",
                "steamid": "SIMULATED_PLAYER_8",
                "name": "Dire Support",
                "team_name": "dire",
                "last_hits_per_second": 0.11,
            },
            {
                "key": "player9",
                "steamid": "SIMULATED_PLAYER_9",
                "name": "Dire Hard Support",
                "team_name": "dire",
                "last_hits_per_second": 0.07,
            },
        ]

        players = {}

        for config in player_configs:
            last_hits = max(
                0,
                int(
                    game_time
                    * config["last_hits_per_second"]
                ),
            )

            players[config["key"]] = {
                "steamid": config["steamid"],
                "name": config["name"],
                "activity": "playing",
                "kills": 0,
                "deaths": 0,
                "assists": 0,
                "last_hits": last_hits,
                "denies": 0,
                "kill_streak": 0,
                "commands_issued": 0,
                "team_name": config["team_name"],
                "gold": 600 + max(0, game_time) * 2,
                "gold_reliable": 0,
                "gold_unreliable":
                    600 + max(0, game_time) * 2,
                "gold_from_hero_kills": 0,
                "gold_from_creep_kills":
                    max(0, game_time) * 2,
                "gold_from_income": 0,
                "gold_from_shared": 0,
                "gpm": int(
                    config["last_hits_per_second"]
                    * 1000
                ),
                "xpm": int(
                    config["last_hits_per_second"]
                    * 1100
                ),
            }

        return {
            "provider": {
                "name": "Dota 2",
                "appid": 570,
                "version": 47,
                "timestamp": int(time.time()),
            },
            "map": {
                "name": "start",
                "matchid": "SIMULATED_MATCH_001",
                "game_time": game_time,
                "clock_time": game_time,
                "daytime": (game_time // 300) % 2 == 0,
                "nightstalker_night": False,
                "game_state": (
                    "DOTA_GAMERULES_STATE_GAME_IN_PROGRESS"
                    if running
                    else "DOTA_GAMERULES_STATE_STRATEGY_TIME"
                ),
                "win_team": "none",
                "customgamename": "",
                "ward_purchase_cooldown": 0,
            },
            "player": players,
            "hero": {
                "id": 1,
                "name": "npc_dota_hero_antimage",
                "level": max(
                    1,
                    min(
                        30,
                        1 + max(0, game_time) // 60,
                    ),
                ),
                "alive": True,
                "respawn_seconds": 0,
                "buyback_cost": 0,
                "buyback_cooldown": 0,
                "health": 700,
                "max_health": 700,
                "health_percent": 100,
                "mana": 300,
                "max_mana": 300,
                "mana_percent": 100,
                "silenced": False,
                "stunned": False,
                "disarmed": False,
                "magicimmune": False,
                "hexed": False,
                "muted": False,
                "break": False,
                "aghanims_scepter": False,
                "aghanims_shard": False,
                "smoked": False,
                "has_debuff": False,
                "selected_unit": True,
                "talent_1": False,
                "talent_2": False,
                "talent_3": False,
                "talent_4": False,
                "talent_5": False,
                "talent_6": False,
                "talent_7": False,
                "talent_8": False,
            },
        }


class Simulator:
    def __init__(self, state: SimulatorState):
        self.state = state
        self.stop_event = threading.Event()
        self.session = requests.Session()

    def run(self) -> None:
        last_tick = time.perf_counter()
        last_send_tick = 0.0

        while not self.stop_event.is_set():
            now = time.perf_counter()
            real_elapsed = now - last_tick
            last_tick = now

            with self.state.lock:
                if self.state.running:
                    self.state.game_time += (
                            real_elapsed * self.state.speed
                    )

            # 每 50 毫秒发送一次，足够支持提示。
            if now - last_send_tick >= 0.05:
                self.send_gsi()
                last_send_tick = now

            time.sleep(0.005)

    def send_gsi(self) -> None:
        payload = self.state.make_gsi_payload()

        try:
            response = self.session.post(
                self.state.target_url,
                json=payload,
                timeout=2,
            )
            response.raise_for_status()

            with self.state.lock:
                self.state.last_send_ok = True
                self.state.last_error = ""
                self.state.last_sent_at = datetime.now(
                    timezone.utc
                ).isoformat(timespec="seconds")
        except requests.RequestException as exc:
            with self.state.lock:
                self.state.last_send_ok = False
                self.state.last_error = str(exc)


def read_json(handler: BaseHTTPRequestHandler) -> Dict[str, Any]:
    try:
        length = int(handler.headers.get("Content-Length", "0"))
        raw = handler.rfile.read(length) if length > 0 else b"{}"
        value = json.loads(raw.decode("utf-8"))
        return value if isinstance(value, dict) else {}
    except (ValueError, json.JSONDecodeError, UnicodeDecodeError):
        return {}


def make_handler(state: SimulatorState):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format_string, *args):
            print(
                f"[模拟器 HTTP] {self.address_string()} "
                f"{format_string % args}",
                flush=True,
            )

        def send_bytes(
            self,
            status: int,
            body: bytes,
            content_type: str,
        ) -> None:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header(
                "Access-Control-Allow-Methods",
                "GET, POST, OPTIONS",
            )
            self.send_header(
                "Access-Control-Allow-Headers",
                "Content-Type",
            )
            self.end_headers()
            self.wfile.write(body)

        def send_json(self, value, status=200):
            body = json.dumps(
                value,
                ensure_ascii=False,
            ).encode("utf-8")

            self.send_bytes(
                status,
                body,
                "application/json; charset=utf-8",
            )

        def do_OPTIONS(self):
            self.send_json({"ok": True})

        def do_GET(self):
            path = urlparse(self.path).path

            if path == "/":
                self.send_bytes(
                    200,
                    HTML.encode("utf-8"),
                    "text/html; charset=utf-8",
                )
                return

            if path == "/api/state":
                self.send_json(state.snapshot())
                return

            self.send_json(
                {
                    "ok": False,
                    "error": f"未知 GET 路径：{path}",
                },
                404,
            )

        def do_POST(self):
            path = urlparse(self.path).path

            print(f"[模拟器] 收到 POST 请求：{path}", flush=True)

            if path == "/api/start":
                with state.lock:
                    state.running = True

                print("[模拟器] 已开始计时", flush=True)
                self.send_json(
                    {
                        "ok": True,
                        "running": True,
                        "game_time": int(state.game_time),
                    }
                )
                return

            if path == "/api/pause":
                with state.lock:
                    state.running = False

                print("[模拟器] 已暂停计时", flush=True)
                self.send_json(
                    {
                        "ok": True,
                        "running": False,
                        "game_time": int(state.game_time),
                    }
                )
                return

            if path == "/api/resume":
                with state.lock:
                    state.running = True

                print("[模拟器] 已继续计时", flush=True)
                self.send_json(
                    {
                        "ok": True,
                        "running": True,
                        "game_time": int(state.game_time),
                    }
                )
                return

            if path == "/api/reset":
                with state.lock:
                    state.game_time = 0.0
                    state.running = False
                    state.last_send_ok = False
                    state.last_error = ""

                print("[模拟器] 已重置", flush=True)
                self.send_json(
                    {
                        "ok": True,
                        "running": False,
                        "game_time": 0,
                    }
                )
                return

            if path == "/api/time":
                value = read_json(self)

                try:
                    game_time = float(value["game_time"])
                except (KeyError, TypeError, ValueError):
                    self.send_json(
                        {
                            "ok": False,
                            "error": "game_time 必须是数字",
                        },
                        400,
                    )
                    return

                with state.lock:
                    state.game_time = game_time

                print(
                    f"[模拟器] 游戏时间已设置为 {game_time}",
                    flush=True,
                )

                self.send_json(
                    {
                        "ok": True,
                        "game_time": int(game_time),
                    }
                )
                return

            if path == "/api/speed":
                value = read_json(self)

                try:
                    speed = float(value["speed"])
                    if speed <= 0:
                        raise ValueError
                except (KeyError, TypeError, ValueError):
                    self.send_json(
                        {
                            "ok": False,
                            "error": "speed 必须是大于 0 的数字",
                        },
                        400,
                    )
                    return

                with state.lock:
                    state.speed = speed

                print(
                    f"[模拟器] 速度已设置为 {speed} 倍",
                    flush=True,
                )

                self.send_json(
                    {
                        "ok": True,
                        "speed": speed,
                    }
                )
                return

            self.send_json(
                {
                    "ok": False,
                    "error": f"未知 POST 路径：{path}",
                },
                404,
            )

    return Handler



def parse_args():
    parser = argparse.ArgumentParser(
        description="模拟 Dota 2 GSI 数据"
    )
    parser.add_argument(
        "--target",
        default="http://127.0.0.1:3000/gsi",
        help="提示工具的 GSI 地址",
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="模拟器控制页面监听地址",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=4000,
        help="模拟器控制页面端口",
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=10.0,
        help="初始模拟速度",
    )
    parser.add_argument(
        "--start-time",
        type=float,
        default=0.0,
        help="初始游戏时间，单位秒",
    )
    parser.add_argument(
        "--auto-start",
        action="store_true",
        help="启动模拟器后立即开始计时",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if args.speed <= 0:
        print("--speed 必须大于 0", file=sys.stderr)
        raise SystemExit(2)

    state = SimulatorState(
        target_url=args.target,
        speed=args.speed,
        game_time=args.start_time,
        running=args.auto_start,
    )

    simulator = Simulator(state)
    simulator_thread = threading.Thread(
        target=simulator.run,
        daemon=True,
    )
    simulator_thread.start()

    server = ThreadingHTTPServer(
        (args.host, args.port),
        make_handler(state),
    )

    print("Dota 2 GSI 模拟器已启动")
    print(f"控制页面：http://{args.host}:{args.port}")
    print(f"GSI 目标：{args.target}")
    print(f"模拟速度：{args.speed} 倍")
    print("按 Ctrl+C 停止")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n正在停止模拟器……")
    finally:
        simulator.stop_event.set()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
