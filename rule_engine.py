from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple


@dataclass(frozen=True)
class Rule:
    id: str
    name: str
    first_time: int
    interval: int
    warning: int
    message: str
    last_time: Optional[int] = None
    enabled: bool = True

    @property
    def first_trigger_time(self) -> int:
        return self.first_time - self.warning

    @classmethod
    def from_dict(cls, value: Dict[str, Any]) -> "Rule":
        raw_last_time = value.get("last_time")

        last_time: Optional[int]
        if raw_last_time is None or raw_last_time == "":
            last_time = None
        else:
            last_time = int(raw_last_time)

        rule = cls(
            id=str(value["id"]),
            name=str(value.get("name", value["id"])),
            first_time=int(value["first_time"]),
            interval=int(value.get("interval", 0)),
            warning=int(value.get("warning", 0)),
            message=str(
                value.get(
                    "message",
                    value.get("name", value["id"]),
                )
            ),
            last_time=last_time,
            enabled=bool(value.get("enabled", True)),
        )

        rule.validate()
        return rule

    def validate(self) -> None:
        if not self.id:
            raise ValueError("规则 id 不能为空")

        if self.first_time < 0:
            raise ValueError(
                f"规则 {self.id}: first_time 不能小于 0"
            )

        if self.interval < 0:
            raise ValueError(
                f"规则 {self.id}: interval 不能小于 0"
            )

        if self.warning < 0:
            raise ValueError(
                f"规则 {self.id}: warning 不能小于 0"
            )

        if self.warning > self.first_time:
            raise ValueError(
                f"规则 {self.id}: warning 不能大于 first_time"
            )

        if self.last_time is not None:
            if self.last_time < 0:
                raise ValueError(
                    f"规则 {self.id}: last_time 不能小于 0"
                )

            if self.last_time < self.first_time:
                raise ValueError(
                    f"规则 {self.id}: last_time 不能小于 first_time"
                )


@dataclass(frozen=True)
class TriggeredEvent:
    rule_id: str
    name: str
    trigger_time: int
    target_time: int
    message: str


@dataclass(frozen=True)
class TimelineEvent:
    rule_id: str
    name: str
    trigger_time: int
    target_time: int
    message: str


class RuleEngine:
    def __init__(self, rules: Iterable[Rule]):
        self.rules: List[Rule] = [
            rule for rule in rules if rule.enabled
        ]

        self.triggered: Set[Tuple[str, int]] = set()
        self.last_game_time: Optional[int] = None

    def reset(self) -> None:
        self.triggered.clear()
        self.last_game_time = None

    def update(self, game_time: int) -> List[TriggeredEvent]:
        game_time = int(game_time)

        # 时间明显回退，视为新对局或模拟器重置。
        if (
            self.last_game_time is not None
            and game_time < self.last_game_time - 2
        ):
            self.reset()

        previous_time = self.last_game_time
        self.last_game_time = game_time

        events: List[TriggeredEvent] = []

        for rule in self.rules:
            for trigger_time, target_time in self._occurrences_up_to(
                rule,
                game_time,
            ):
                key = (rule.id, target_time)

                if key in self.triggered:
                    continue

                if previous_time is None:
                    should_trigger = trigger_time == game_time
                else:
                    should_trigger = (
                        previous_time < trigger_time <= game_time
                    )

                if should_trigger:
                    self.triggered.add(key)

                    events.append(
                        TriggeredEvent(
                            rule_id=rule.id,
                            name=rule.name,
                            trigger_time=trigger_time,
                            target_time=target_time,
                            message=rule.message,
                        )
                    )

        events.sort(
            key=lambda item: (
                item.trigger_time,
                item.rule_id,
            )
        )

        return events

    def timeline(
        self,
        game_time: int,
        past_count: int = 1,
        future_count: int = 2,
    ) -> Tuple[List[TimelineEvent], List[TimelineEvent]]:
        """
        返回：
        - 已发生的最近 past_count 条
        - 即将发生的 future_count 条

        last_time 表示目标事件的截至时间。
        当目标时间大于 last_time 时，不再生成该规则的事件。
        """
        game_time = int(game_time)

        past_candidates: List[TimelineEvent] = []
        future_candidates: List[TimelineEvent] = []

        for rule in self.rules:
            previous_occurrence = self._previous_occurrence(
                rule,
                game_time,
            )

            if previous_occurrence is not None:
                trigger_time, target_time = previous_occurrence

                past_candidates.append(
                    TimelineEvent(
                        rule_id=rule.id,
                        name=rule.name,
                        trigger_time=trigger_time,
                        target_time=target_time,
                        message=rule.message,
                    )
                )

            future_occurrences = self._future_occurrences(
                rule,
                game_time,
                future_count,
            )

            for trigger_time, target_time in future_occurrences:
                future_candidates.append(
                    TimelineEvent(
                        rule_id=rule.id,
                        name=rule.name,
                        trigger_time=trigger_time,
                        target_time=target_time,
                        message=rule.message,
                    )
                )

        # 越靠近当前时间的过去事件排前面。
        past_candidates.sort(
            key=lambda item: (
                -item.trigger_time,
                item.rule_id,
            )
        )

        # 越早发生的未来事件排前面。
        future_candidates.sort(
            key=lambda item: (
                item.trigger_time,
                item.rule_id,
            )
        )

        return (
            past_candidates[:past_count],
            future_candidates[:future_count],
        )

    @staticmethod
    def _occurrences_up_to(
        rule: Rule,
        game_time: int,
    ) -> List[Tuple[int, int]]:
        first_trigger = rule.first_trigger_time

        if game_time < first_trigger:
            return []

        if rule.interval == 0:
            if (
                rule.last_time is not None
                and rule.first_time > rule.last_time
            ):
                return []

            return [
                (
                    first_trigger,
                    rule.first_time,
                )
            ]

        count = (
            game_time - first_trigger
        ) // rule.interval

        occurrences: List[Tuple[int, int]] = []

        for index in range(count + 1):
            trigger_time = (
                first_trigger
                + index * rule.interval
            )

            target_time = (
                rule.first_time
                + index * rule.interval
            )

            if (
                rule.last_time is not None
                and target_time > rule.last_time
            ):
                break

            occurrences.append(
                (
                    trigger_time,
                    target_time,
                )
            )

        return occurrences

    @staticmethod
    def _previous_occurrence(
        rule: Rule,
        game_time: int,
    ) -> Optional[Tuple[int, int]]:
        first_trigger = rule.first_trigger_time

        if game_time < first_trigger:
            return None

        if rule.interval == 0:
            if (
                rule.last_time is not None
                and rule.first_time > rule.last_time
            ):
                return None

            return (
                first_trigger,
                rule.first_time,
            )

        index = (
            game_time - first_trigger
        ) // rule.interval

        target_time = (
            rule.first_time
            + index * rule.interval
        )

        if (
            rule.last_time is not None
            and target_time > rule.last_time
        ):
            # 当前时间已经超过最后一次目标时间，
            # 返回 last_time 对应的最后一个事件。
            index = (
                rule.last_time - rule.first_time
            ) // rule.interval

            target_time = (
                rule.first_time
                + index * rule.interval
            )

        return (
            first_trigger + index * rule.interval,
            target_time,
        )

    @staticmethod
    def _future_occurrences(
        rule: Rule,
        game_time: int,
        count: int,
    ) -> List[Tuple[int, int]]:
        if count <= 0:
            return []

        first_trigger = rule.first_trigger_time

        if rule.interval == 0:
            if (
                first_trigger > game_time
                and (
                    rule.last_time is None
                    or rule.first_time <= rule.last_time
                )
            ):
                return [
                    (
                        first_trigger,
                        rule.first_time,
                    )
                ]

            return []

        if game_time < first_trigger:
            first_index = 0
        else:
            first_index = (
                (game_time - first_trigger)
                // rule.interval
            ) + 1

        occurrences: List[Tuple[int, int]] = []

        for index in range(
            first_index,
            first_index + count,
        ):
            trigger_time = (
                first_trigger
                + index * rule.interval
            )

            target_time = (
                rule.first_time
                + index * rule.interval
            )

            if (
                rule.last_time is not None
                and target_time > rule.last_time
            ):
                break

            occurrences.append(
                (
                    trigger_time,
                    target_time,
                )
            )

        return occurrences



def get_game_time(
    state: Dict[str, Any],
) -> Optional[int]:
    map_data = state.get("map")

    if not isinstance(map_data, dict):
        return None

    value = map_data.get("game_time")

    if value is None:
        value = map_data.get("clock_time")

    if value is None:
        return None

    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def is_game_in_progress(
    state: Dict[str, Any],
) -> bool:
    map_data = state.get("map")

    if not isinstance(map_data, dict):
        return False

    return (
        map_data.get("game_state")
        == "DOTA_GAMERULES_STATE_GAME_IN_PROGRESS"
    )


def format_game_time(
    seconds: Optional[int],
) -> str:
    if seconds is None:
        return "--:--"

    sign = "-" if seconds < 0 else ""
    seconds = abs(int(seconds))

    minutes, remaining = divmod(
        seconds,
        60,
    )

    return (
        f"{sign}{minutes}:"
        f"{remaining:02d}"
    )
