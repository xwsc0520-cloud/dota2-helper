import unittest

from rule_engine import Rule, RuleEngine, get_game_time


class RuleEngineTests(unittest.TestCase):
    def test_one_time_rule(self):
        engine = RuleEngine(
            [
                Rule(
                    id="test",
                    name="测试",
                    first_time=10,
                    interval=0,
                    warning=0,
                    message="测试提醒",
                )
            ]
        )

        self.assertEqual(engine.update(0), [])
        events = engine.update(10)

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].target_time, 10)

        # 同一目标时间不能重复触发。
        self.assertEqual(engine.update(11), [])

    def test_lotus_warning(self):
        engine = RuleEngine(
            [
                Rule(
                    id="lotus",
                    name="莲花",
                    first_time=180,
                    interval=180,
                    warning=20,
                    message="20秒后刷新",
                )
            ]
        )

        self.assertEqual(engine.update(159), [])

        events = engine.update(160)

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].trigger_time, 160)
        self.assertEqual(events[0].target_time, 180)

    def test_skipped_second_still_triggers(self):
        engine = RuleEngine(
            [
                Rule(
                    id="lotus",
                    name="莲花",
                    first_time=180,
                    interval=180,
                    warning=20,
                    message="20秒后刷新",
                )
            ]
        )

        engine.update(159)
        events = engine.update(162)

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].trigger_time, 160)

    def test_recurring_rule(self):
        engine = RuleEngine(
            [
                Rule(
                    id="lotus",
                    name="莲花",
                    first_time=180,
                    interval=180,
                    warning=20,
                    message="20秒后刷新",
                )
            ]
        )

        engine.update(339)
        events = engine.update(340)

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].target_time, 360)

    def test_time_rollback_resets_match(self):
        engine = RuleEngine(
            [
                Rule(
                    id="test",
                    name="测试",
                    first_time=10,
                    interval=0,
                    warning=0,
                    message="测试提醒",
                )
            ]
        )

        engine.update(0)
        self.assertEqual(len(engine.update(10)), 1)

        # 回退到 0，视为新对局。
        engine.update(0)
        self.assertEqual(len(engine.update(10)), 1)

    def test_get_game_time(self):
        state = {"map": {"game_time": 180}}
        self.assertEqual(get_game_time(state), 180)

        fallback = {"map": {"clock_time": "181"}}
        self.assertEqual(get_game_time(fallback), 181)

        self.assertIsNone(get_game_time({}))


if __name__ == "__main__":
    unittest.main()
