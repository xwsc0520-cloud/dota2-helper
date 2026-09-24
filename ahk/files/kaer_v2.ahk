#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk


; ============================================================
; 基础配置
; ============================================================

global dl := 100

; ============================================================
; 英雄等级与 R 技能 CD 配置
; ============================================================

global HeroLevel := 1
global MinHeroLevel := 1
global MaxHeroLevel := 30

; R 技能 1~30 级 CD，单位：毫秒
;
; 下面的数值请按照实际游戏中的 R 技能 CD 修改。
; 第 1 个元素对应 1 级，第 30 个元素对应 30 级。
;
global RLevelCDList := [
    7000,   ; 1级
    6700,   ; 2级
    6400,   ; 3级
    6100,   ; 4级
    5800,   ; 5级
    5200,   ; 6级
    4900,   ; 7级
    4600,   ; 8级
    4300,   ; 9级
    4000,   ; 10级
    3700,   ; 11级
    3100,   ; 12级
    2800,   ; 13级
    2500,   ; 14级
    2200,   ; 15级
    1900,   ; 16级
    1600,   ; 17级
    1000,   ; 18级
    700,    ; 19级
    400,    ; 20级
    100,    ; 21级
    0,      ; 22级
    0,      ; 23级
    0,      ; 24级
    0,      ; 25级
    0,      ; 26级
    0,      ; 27级
    0,      ; 28级
    0,      ; 29级
    0,      ; 30级
]

; 最近一次发送 R 切技能按键的时间
global RLastCast := 0



; ============================================================
; 技能配置
;
; combo 只保存用于区分技能的 q/w/e 组合，不包含 r。
; 实际切换技能时会自动补上 r。
;
; cast 保存技能切换完成后的释放操作。
; 字符串 "df" 会根据技能实际槽位替换成 d 或 f。
; ============================================================

global SkillConfigs := [
    {
        hotkey: "q",
        combo: "qww",
        name: "吹风",
        cd: 27000,
        cast: ["df"]
    },
    {
        hotkey: "w",
        combo: "qwe",
        name: "推波",
        cd: 36000,
        cast: ["df"]
    },
    {
        hotkey: "s",
        combo: "qqe",
        name: "冰墙",
        cd: 23000,
        cast: ["df"]
    },
    {
        hotkey: "d",
        combo: "qee",
        name: "火人",
        cd: 27000,
        cast: [
            "df",
            100,
            "a",
            "e",
            "e",
            "e",
            "{CapsLock}"
        ]
    },
    {
        hotkey: "e",
        combo: "wwe",
        name: "灵动",
        cd: 15000,
        cast: [
            {key: "df", mods: "!"},
            100,
            "a",
            "e",
            "e",
            "e"
        ]
    },
    {
        hotkey: "a",
        combo: "qqq",
        name: "极冷",
        cd: 19000,
        cast: ["df"]
    },
    {
        hotkey: "f",
        combo: "qqw",
        name: "隐身",
        cd: 40000,
        cast: ["df"]
    },
    {
        hotkey: "c",
        combo: "www",
        name: "雷爆",
        cd: 27000,
        cast: ["df"]
    },
    {
        hotkey: "x",
        combo: "eee",
        name: "天火",
        cd: 23000,
        cast: ["df"]
    },
    {
        hotkey: "z",
        combo: "wee",
        name: "陨石",
        cd: 50000,
        cast: ["df"]
    }
]


; ============================================================
; 自动生成技能数据
; ============================================================

global Skills := []
global SkillByHotkey := Map()
global SkillByName := Map()
global SkillCD := Map()
global SkillLastCast := Map()

for config in SkillConfigs {
    skill := config.name

    Skills.Push(skill)
    SkillByHotkey[config.hotkey] := skill
    SkillByName[skill] := config
    SkillCD[skill] := config.cd
    SkillLastCast[skill] := 0
}


; ============================================================
; 技能 CD 布局
;
; 第二行：Q W E
; 第三行：A S D F
; 第四行：Z X C
; ============================================================

global HotkeyLayout := [
    ["q", "w", "e"],
    ["a", "s", "d", "f"],
    ["z", "x", "c"]
]


; ============================================================
; 当前 D/F 槽位
; ============================================================

global DSkill := ""
global FSkill := ""


; ============================================================
; UI 配置
; ============================================================

; 0~255：
;   数值越小越透明
;   255 为完全不透明
global GUI_TRANSPARENCY := 196

global CDCellWidth := 120
global CDCellHeight := 38

; 下方第二行有四格，所以窗口宽度按四格计算
global CDTotalWidth := CDCellWidth * 4

; 第一行 D/F 槽位信息的高度
global SlotRowHeight := 62

global CDWindowWidth := CDTotalWidth + 16
global CDWindowHeight := (
    SlotRowHeight
    + CDCellHeight * 3
    + 16
)

; ============================================================
; 创建悬浮窗
; ============================================================

global GuiCD := Gui(
    "+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20",
    "技能CD"
)

GuiCD.BackColor := "202020"
GuiCD.MarginX := 8
GuiCD.MarginY := 8


; ============================================================
; 第一行：D/F 槽位
; ============================================================

GuiCD.SetFont("s13 Bold cFFFFFF", "Segoe UI")

global DSlotText := GuiCD.AddText(
    "x8 y8"
    . " w" Floor(CDTotalWidth / 2)
    . " h" SlotRowHeight
    . " Center",
    "D槽：未同步"
)

global FSlotText := GuiCD.AddText(
    "x" (8 + Floor(CDTotalWidth / 2))
    . " y8"
    . " w" Floor(CDTotalWidth / 2)
    . " h" SlotRowHeight
    . " Center",
    "F槽：未同步"
)

global HeroLevelText := GuiCD.AddText(
    "x8 y42"
    . " w" Floor(CDTotalWidth / 2)
    . " h20"
    . " Center",
    "等级：1"
)

global RCDText := GuiCD.AddText(
    "x" (8 + Floor(CDTotalWidth / 2))
    . " y42"
    . " w" Floor(CDTotalWidth / 2)
    . " h20"
    . " Center",
    "R：就绪"
)



; ============================================================
; 下方三行：技能 CD
; ============================================================

global CDHotkeyText := Map()

for rowIndex, rowItems in HotkeyLayout {
    rowWidth := rowItems.Length * CDCellWidth

    rowStartX := 8

    ; 第一行槽位状态结束后，开始绘制技能 CD
    rowY := 8 + SlotRowHeight + (rowIndex - 1) * CDCellHeight

    for colIndex, hkName in rowItems {
        cellX := rowStartX + (colIndex - 1) * CDCellWidth

        controlName := "CD_" hkName

        GuiCD.SetFont("s10 Norm cFFFFFF", "Segoe UI")

        GuiCD.AddText(
            "x" cellX
            . " y" rowY
            . " w" CDCellWidth
            . " h" CDCellHeight
            . " Center +0x200 v" controlName,
            SkillByHotkey[hkName] "`n检测中"
        )

        CDHotkeyText[hkName] := GuiCD[controlName]
    }
}


; ============================================================
; 显示悬浮窗并设置整体透明度
; ============================================================

GuiCD.Show(
    "x20 y200"
    . " w" CDWindowWidth
    . " h" CDWindowHeight
    . " NoActivate"
)

WinSetTransparent(GUI_TRANSPARENCY, "ahk_id " GuiCD.Hwnd)

SetTimer(UpdateCDGui, 100)


; ============================================================
; 输入绑定
; ============================================================

PgUp::ShowCDGui()
PgDn::HideCDGui()

; 上下方向键调整英雄等级
Up::ChangeHeroLevel(1)
Down::ChangeHeroLevel(-1)


; 保留 Esc 原功能，并重置本地槽位和 CD 状态
~Esc::ResetAllState()

; 单独按 D/F，释放对应槽位技能
$d::CastCurrentSlot("d")
$f::CastCurrentSlot("f")

; 禁用LAlt
$LAlt::Return

RegisterAllSkillHotkeys()


; ============================================================
; 注册所有组合热键
; ============================================================

RegisterAllSkillHotkeys() {
    global SkillConfigs

    for config in SkillConfigs
        RegisterOneSkillHotkey(config)
}


RegisterOneSkillHotkey(config) {
    skill := config.name
    hk := config.hotkey

    Hotkey(
        "Space & " hk,
        (*) => SwitchThenCast(skill)
    )

    Hotkey(
        "LAlt & " hk,
        (*) => SwitchOnly(skill)
    )
}


; ============================================================
; Space 组合：只切技能
; ============================================================

SwitchOnly(skill) {
    if skill = ""
        return

    SwitchSkill(skill)
}


; ============================================================
; LAlt 组合：切技能并释放
;
; 不使用 CD 阻止切换或释放。
; ============================================================

SwitchThenCast(skill) {
    if skill = ""
        return

    ; 技能已经在 D 槽，直接释放
    ; 不发送 R，不触发 R CD
    if DSkill = skill {
        CastSkill(skill, "d")
        return
    }

    if FSkill = skill {
        CastSkill(skill, "f")
        return
    }

    ; 技能不在 D/F，先切入 D
    if !SwitchSkill(skill)
        return

    CastSkill(skill, "d")
}




; ============================================================
; 切换技能
;
; 规则：
;
; 1. 如果技能已经在 D，仍然重新发送切换按键，
;    但不修改脚本中的 D/F 槽位状态。
;
; 2. 如果技能在 F，发送切换按键并交换 D/F。
;
; 3. 如果技能不在 D/F，新技能进入 D，
;    原 D 进入 F，原 F 被顶掉。
;
; 4. CD 不会阻止切技能。
; ============================================================

SwitchSkill(skill) {
    global DSkill, FSkill

    if skill = ""
        return false

    ; 技能已经在 D 槽，不需要再次切换
    ; 不发送 R，也不会触发 R CD
    if DSkill = skill
        return true

    ; R CD 未完成，禁止切换
    if !IsRReady()
        return false

    ; 技能已经在 F 槽：切到 D，并交换槽位
    if FSkill = skill {
        if !SendSwitchCommand(skill, true)
            return false

        oldD := DSkill
        DSkill := skill
        FSkill := oldD

        return true
    }

    ; 如果 D 正在 CD，而 F 已经可用：
    ; 先把 F 切到 D
    if DSkill != "" && FSkill != "" {
        if !IsSkillReady(DSkill) && IsSkillReady(FSkill) {
            SwitchFToD()
        }
    }

    ; 新技能切入 D 槽
    if !SendSwitchCommand(skill, false)
        return false

    FSkill := DSkill
    DSkill := skill

    return true
}




; ============================================================
; 将 F 槽技能切到 D
; ============================================================

SwitchFToD() {
    global DSkill, FSkill

    if FSkill = ""
        return

    ; R CD 未好，禁止切换
    if !IsRReady()
        return

    skill := FSkill
    oldD := DSkill

    if !SendSwitchCommand(skill, true)
        return

    DSkill := skill
    FSkill := oldD
}




; ============================================================
; 发送切技能组合
;
; 配置中的 combo 不含 r。
; 实际发送时自动追加 r。
; ============================================================

SendSwitchCommand(skill, f_to_d) {
    global SkillByName
    global RLastCast

    if skill = ""
        return false

    if !SkillByName.Has(skill)
        return false

    if !IsRReady()
        return false

    config := SkillByName[skill]
    combo := []

    Loop Parse, config.combo
        combo.Push(A_LoopField)

    combo.Push("r")

    AddCombo(combo)

    if !f_to_d {
        RLastCast := A_TickCount
    }

    return true
}




; ============================================================
; 单独按 D/F 释放当前槽位技能
;
; 即使技能处于 CD，也允许发送释放键。
; ============================================================

CastCurrentSlot(position) {
    global DSkill, FSkill

    if position = "d"
        skill := DSkill
    else if position = "f"
        skill := FSkill
    else
        return

    if skill = ""
        return

    if !IsSkillReady(skill) {
        return
    }

    AddCombo([position])
    MarkSkillCast(skill)
}


; ============================================================
; 执行技能释放
;
; 不使用 CD 阻止释放。
; ============================================================

CastSkill(skill, position) {
    global SkillByName
    global dl

    if skill = ""
        return

    if !SkillByName.Has(skill)
        return

    if !IsSkillReady(skill) {
        return
    }

    config := SkillByName[skill]
    combo := [dl]

    for item in config.cast {
        ; 普通字符串 d 根据实际槽位替换为 d/f
        if Type(item) = "String" && item = "df" {
            combo.Push(position)
            continue
        }

        ; Alt+D 根据实际槽位替换为 Alt+D/Alt+F
        if IsAltDObject(item) {
            if position = "f"
                combo.Push({key: "f", mods: "!"})
            else
                combo.Push({key: "d", mods: "!"})

            continue
        }

        combo.Push(item)
    }

    AddCombo(combo)
    MarkSkillCast(skill)
}


; ============================================================
; 判断队列项是否为 Alt+D
; ============================================================

IsAltDObject(item) {
    if !IsObject(item)
        return false

    try {
        return item.key = "df" && item.mods = "!"
    } catch {
        return false
    }
}


; ============================================================
; 记录技能释放时间
; ============================================================

MarkSkillCast(skill) {
    global SkillLastCast

    SkillLastCast[skill] := A_TickCount
}


; ============================================================
; 判断技能是否冷却完成
;
; 只用于 UI 显示和槽位整理，
; 不用于阻止切技能或释放技能。
; ============================================================

IsSkillReady(skill) {
    global SkillCD, SkillLastCast

    if skill = ""
        return false

    if !SkillCD.Has(skill)
        return true

    if !SkillLastCast.Has(skill)
        return true

    return A_TickCount - SkillLastCast[skill] >= SkillCD[skill]
}


; ============================================================
; 获取技能剩余 CD
; ============================================================

GetSkillRemaining(skill) {
    global SkillCD, SkillLastCast

    if skill = ""
        return 0

    if !SkillCD.Has(skill)
        return 0

    if !SkillLastCast.Has(skill)
        return 0

    remaining := SkillCD[skill] - (
        A_TickCount - SkillLastCast[skill]
    )

    return Max(remaining, 0)
}


; ============================================================
; Esc：重置所有本地状态
; ============================================================

ResetAllState() {
    global DSkill, FSkill
    global SkillLastCast, Skills
    global RLastCast

    DSkill := ""
    FSkill := ""
    RLastCast := 0

    for skill in Skills
        SkillLastCast[skill] := 0
}



; ============================================================
; 更新悬浮窗
; ============================================================

UpdateCDGui() {
    global HotkeyLayout
    global SkillByHotkey
    global CDHotkeyText
    global DSkill
    global FSkill
    global DSlotText
    global FSlotText
    global HeroLevel
    global HeroLevelText
    global RCDText


    ; --------------------------------------------------------
    ; 第一行：D/F 槽位状态
    ;
    ; 槽位技能颜色与对应技能的 CD 颜色一致：
    ;   可用：绿色
    ;   CD中：红色
    ;   未同步：灰色
    ; --------------------------------------------------------

    if DSkill = "" {
        DSlotText.Text := "D槽：未同步"

        DSlotText.SetFont(
            "s13 Bold cAAAAAA",
            "Segoe UI"
        )
    } else {
        config := SkillByName[DSkill]
        hotkey := StrUpper(config.hotkey)

        DSlotText.Text := "D槽：" DSkill " " hotkey

        if GetSkillRemaining(DSkill) <= 0 {
            DSlotText.SetFont(
                "s13 Bold c00FF00",
                "Segoe UI"
            )
        } else {
            DSlotText.SetFont(
                "s13 Bold cFF3030",
                "Segoe UI"
            )
        }
    }

    if FSkill = "" {
        FSlotText.Text := "F槽：未同步"

        FSlotText.SetFont(
            "s13 Bold cAAAAAA",
            "Segoe UI"
        )
    } else {
        config := SkillByName[FSkill]
        hotkey := StrUpper(config.hotkey)

        FSlotText.Text := "F槽：" FSkill " " hotkey

        if GetSkillRemaining(FSkill) <= 0 {
            FSlotText.SetFont(
                "s13 Bold c00FF00",
                "Segoe UI"
            )
        } else {
            FSlotText.SetFont(
                "s13 Bold cFF3030",
                "Segoe UI"
            )
        }
    }


    ; --------------------------------------------------------
    ; 下方三行：技能 CD 状态
    ; --------------------------------------------------------

    for rowItems in HotkeyLayout {
        for hkName in rowItems {
            if !SkillByHotkey.Has(hkName)
                continue

            skill := SkillByHotkey[hkName]
            remaining := GetSkillRemaining(skill)

            isInSlot := (skill = DSkill || skill = FSkill)

            if remaining <= 0 {
                displayText := skill

                if isInSlot {
                    ; 可用，并且位于 D/F 槽：很粗的亮绿色
                    CDHotkeyText[hkName].SetFont(
                        "s11 Bold c30FF30",
                        "Arial Black"
                    )
                } else {
                    if IsRReady() {
                        ; 可用，但不在 D/F 槽，有大：蓝色
                        CDHotkeyText[hkName].SetFont(
                            "s10 Norm c8080FF",
                            "Segoe UI"
                        )
                    } else {
                        ; 可用，但不在 D/F 槽，没大：普通白色
                        CDHotkeyText[hkName].SetFont(
                            "s10 Norm cFFFFFF",
                            "Segoe UI"
                        )
                    }
                }
            } else {
                seconds := Round(remaining / 1000, 1)
                displayText := skill " " seconds "秒"

                ; CD 中：红色普通字体
                CDHotkeyText[hkName].SetFont(
                    "s10 Norm cFF3030",
                    "Segoe UI"
                )
            }

            CDHotkeyText[hkName].Text := displayText
        }
    }

    ; --------------------------------------------------------
    ; 英雄等级与 R CD
    ; --------------------------------------------------------

    rRemaining := GetRRemaining()

    HeroLevelText.Text := "等级：" HeroLevel

    if rRemaining <= 0 {
        RCDText.Text := "R：就绪"

        RCDText.SetFont(
            "s10 Bold c00FF00",
            "Segoe UI"
        )
    } else {
        RCDText.Text := "R：" Round(rRemaining / 1000, 1) "秒"

        RCDText.SetFont(
            "s10 Bold cFF3030",
            "Segoe UI"
        )
    }

}

; ============================================================
; 显示 CD UI
; ============================================================

ShowCDGui() {
    global GuiCD

    GuiCD.Show("NoActivate")
}


; ============================================================
; 隐藏 CD UI
; ============================================================

HideCDGui() {
    global GuiCD

    GuiCD.Hide()
}


; ============================================================
; 调整英雄等级
; ============================================================

ChangeHeroLevel(amount) {
    global HeroLevel
    global MinHeroLevel
    global MaxHeroLevel
    global RLevelCDList

    newLevel := HeroLevel + amount

    if newLevel < MinHeroLevel
        newLevel := MinHeroLevel

    if newLevel > MaxHeroLevel
        newLevel := MaxHeroLevel

    HeroLevel := newLevel

    ; 防止等级超过实际 CD 配置数组长度
    if HeroLevel > RLevelCDList.Length
        HeroLevel := RLevelCDList.Length
}

; ============================================================
; 获取当前等级的 R CD
; ============================================================

GetCurrentRCD() {
    global HeroLevel
    global RLevelCDList

    if RLevelCDList.Length = 0
        return 0

    level := HeroLevel

    if level < 1
        level := 1

    if level > RLevelCDList.Length
        level := RLevelCDList.Length

    return RLevelCDList[level]
}

; ============================================================
; 判断 R 是否可以使用
; ============================================================

IsRReady() {
    global RLastCast

    if RLastCast = 0
        return true

    return A_TickCount - RLastCast >= GetCurrentRCD()
}


; ============================================================
; 获取 R 剩余 CD
; ============================================================

GetRRemaining() {
    global RLastCast

    if RLastCast = 0
        return 0

    remaining := GetCurrentRCD() - (
        A_TickCount - RLastCast
    )

    return Max(remaining, 0)
}
