; 基础配置
global dl := 100

; 英雄等级与 R 技能 CD，单位：毫秒
global HeroLevel := 1
global MinHeroLevel := 1
global MaxHeroLevel := 30

; 第 1 个元素对应 1 级，第 30 个元素对应 30 级
global RLevelCDList := [
    7000, 6700, 6400, 6100, 5800,
    5200, 4900, 4600, 4300, 4000,
    3700, 3100, 2800, 2500, 2200,
    1900, 1600, 1000, 700, 400,
    100, 0, 0, 0, 0,
    0, 0, 0, 0, 0
]

; combo 不包含 r，切换时自动追加
; cast 中的 "df" 会按实际槽位替换为 d/f
global SkillConfigs := [
    {
        hotkey: "q", combo: "qww", name: "吹风",
        cd: 27000, cast: ["df"]
    },
    {
        hotkey: "w", combo: "qwe", name: "推波",
        cd: 36000, cast: ["df"]
    },
    {
        hotkey: "s", combo: "qqe", name: "冰墙",
        cd: 23000, cast: ["df"]
    },
    {
        hotkey: "d", combo: "qee", name: "火人",
        cd: 27000,
        cast: ["df", dl, "a", "e", "e", "e", "{CapsLock}"]
    },
    {
        hotkey: "e", combo: "wwe", name: "灵动",
        cd: 15000,
        cast: [{key: "df", mods: "!"}, dl, "a", "e", "e", "e"]
    },
    {
        hotkey: "a", combo: "qqq", name: "极冷",
        cd: 19000, cast: ["df", "x"]
    },
    {
        hotkey: "f", combo: "qqw", name: "隐身",
        cd: 40000, cast: ["df"]
    },
    {
        hotkey: "c", combo: "www", name: "雷爆",
        cd: 27000, cast: ["df"]
    },
    {
        hotkey: "x", combo: "eee", name: "天火",
        cd: 23000, cast: ["df"]
    },
    {
        hotkey: "z", combo: "wee", name: "陨石",
        cd: 50000, cast: ["df"]
    }
]

; UI 布局
global HotkeyLayout := [
    ["q", "w", "e"],
    ["a", "s", "d", "f"],
    ["z", "x", "c"]
]

global GUI_TRANSPARENCY := 196
global CDCellWidth := 120
global CDCellHeight := 38
global CDTotalWidth := CDCellWidth * 4
global SlotRowHeight := 62
global CDWindowWidth := CDTotalWidth + 16
global CDWindowHeight := SlotRowHeight + CDCellHeight * 3 + 34
