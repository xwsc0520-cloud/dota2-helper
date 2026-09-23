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
; 技能配置
;
; combo 只保存用于区分技能的 q/w/e 组合，不包含 r。
; 实际切换技能时会自动补上 r。
;
; cast 保存技能切换完成后的释放操作。
; 字符串 "d" 会根据技能实际槽位替换成 d 或 f。
; ============================================================

global SkillConfigs := [
    {
        hotkey: "q",
        combo: "qww",
        name: "吹风",
        cd: 27000,
        cast: ["d"]
    },
    {
        hotkey: "w",
        combo: "qwe",
        name: "推波",
        cd: 36000,
        cast: ["d"]
    },
    {
        hotkey: "e",
        combo: "qqe",
        name: "冰墙",
        cd: 23000,
        cast: ["d"]
    },
    {
        hotkey: "a",
        combo: "qee",
        name: "火人",
        cd: 27000,
        cast: [
            "d",
            100,
            "a",
            "{CapsLock}",
            "e",
            "e",
            "e"
        ]
    },
    {
        hotkey: "s",
        combo: "wwe",
        name: "灵动",
        cd: 15000,
        cast: [
            {key: "d", mods: "!"},
            "a",
            "e",
            "e",
            "e"
        ]
    },
    {
        hotkey: "d",
        combo: "qqq",
        name: "极冷",
        cd: 19000,
        cast: ["d"]
    },
    {
        hotkey: "f",
        combo: "qqw",
        name: "隐身",
        cd: 40000,
        cast: ["d"]
    },
    {
        hotkey: "z",
        combo: "www",
        name: "雷爆",
        cd: 27000,
        cast: ["d"]
    },
    {
        hotkey: "x",
        combo: "eee",
        name: "天火",
        cd: 23000,
        cast: ["d"]
    },
    {
        hotkey: "c",
        combo: "wee",
        name: "陨石",
        cd: 50000,
        cast: ["d"]
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
global GUI_TRANSPARENCY := 128

global CDCellWidth := 120
global CDCellHeight := 65

; 下方第二行有四格，所以窗口宽度按四格计算
global CDTotalWidth := CDCellWidth * 4

; 第一行 D/F 槽位信息的高度
global SlotRowHeight := 38

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
    "+AlwaysOnTop -Caption +ToolWindow",
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
    . " Left",
    "D槽：未同步"
)

global FSlotText := GuiCD.AddText(
    "x" (8 + Floor(CDTotalWidth / 2))
    . " y8"
    . " w" Floor(CDTotalWidth / 2)
    . " h" SlotRowHeight
    . " Left",
    "F槽：未同步"
)


; ============================================================
; 下方三行：技能 CD
; ============================================================

global CDHotkeyText := Map()

for rowIndex, rowItems in HotkeyLayout {
    rowWidth := rowItems.Length * CDCellWidth

    ; 每一行按四格宽度居中
    rowStartX := 8 + Floor((CDTotalWidth - rowWidth) / 2)

    ; 第一行槽位状态结束后，开始绘制技能 CD
    rowY := 8 + SlotRowHeight + (rowIndex - 1) * CDCellHeight

    for colIndex, hkName in rowItems {
        cellX := rowStartX + (colIndex - 1) * CDCellWidth

        GuiCD.SetFont("s10 Bold cFFFFFF", "Segoe UI")

        GuiCD.AddText(
            "x" cellX
            . " y" rowY
            . " w" CDCellWidth
            . " h20 Center",
            "[" StrUpper(hkName) "]"
        )

        controlName := "CD_" hkName

        GuiCD.SetFont("s10 Norm cFFFFFF", "Segoe UI")

        GuiCD.AddText(
            "x" cellX
            . " y" (rowY + 21)
            . " w" CDCellWidth
            . " h40 Center v" controlName,
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

; 保留 Esc 原功能，并重置本地槽位和 CD 状态
~Esc::ResetAllState()

; 单独按 D/F，释放对应槽位技能
$d::CastCurrentSlot("d")
$f::CastCurrentSlot("f")

; 禁用LAlt
LAlt::Return

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

    ; Space + 技能键：只切技能
    Hotkey(
        "~Space & " hk,
        (*) => SwitchOnly(skill)
    )

    ; LAlt + 技能键：切技能并释放
    Hotkey(
        "~LAlt & " hk,
        (*) => SwitchThenCast(skill)
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

    ; 不论技能当前在 D、F 还是不在槽位，
    ; 都先实际发送一次切技能组合。
    SwitchSkill(skill)

    ; 切完后技能应处于 D 槽，因此按 D 释放。
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
        return

    ; 已经在 D：仍然实际发送切换组合
    if DSkill = skill {
        SendSwitchCommand(skill)
        return
    }

    ; 已经在 F：切到 D，并交换槽位
    if FSkill = skill {
        SendSwitchCommand(skill)

        oldD := DSkill
        DSkill := skill
        FSkill := oldD

        return
    }

    ; 如果 D 正在 CD，而 F 已经可用：
    ; 先把 F 切到 D，尽量避免后续把可用技能顶掉。
    ;
    ; CD 只影响槽位整理，不会阻止技能切换。
    if DSkill != "" && FSkill != "" {
        if !IsSkillReady(DSkill) && IsSkillReady(FSkill)
            SwitchFToD()
    }

    ; 新技能切入
    SendSwitchCommand(skill)

    FSkill := DSkill
    DSkill := skill
}


; ============================================================
; 将 F 槽技能切到 D
; ============================================================

SwitchFToD() {
    global DSkill, FSkill

    if FSkill = ""
        return

    skill := FSkill
    oldD := DSkill

    SendSwitchCommand(skill)

    DSkill := skill
    FSkill := oldD
}


; ============================================================
; 发送切技能组合
;
; 配置中的 combo 不含 r。
; 实际发送时自动追加 r。
; ============================================================

SendSwitchCommand(skill) {
    global SkillByName

    if skill = ""
        return

    if !SkillByName.Has(skill)
        return

    config := SkillByName[skill]
    combo := []

    Loop Parse, config.combo
        combo.Push(A_LoopField)

    ; 实际切技能必须按 r
    combo.Push("r")

    AddCombo(combo)
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

    AddCombo([position])
    MarkSkillCast(skill)
}


; ============================================================
; 执行技能释放
;
; 不使用 CD 阻止释放。
; ============================================================

CastSkill(skill, position := "d") {
    global SkillByName
    global dl

    if skill = ""
        return

    if !SkillByName.Has(skill)
        return

    config := SkillByName[skill]
    combo := [dl]

    for item in config.cast {
        ; 普通字符串 d 根据实际槽位替换为 d/f
        if Type(item) = "String" && item = "d" {
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
        return item.key = "d" && item.mods = "!"
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

    DSkill := ""
    FSkill := ""

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
        DSlotText.Text := "D槽：" DSkill

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
        FSlotText.Text := "F槽：" FSkill

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

            if remaining <= 0 {
                displayText := skill "`n可用"

                CDHotkeyText[hkName].SetFont(
                    "s10 Norm c00FF00",
                    "Segoe UI"
                )
            } else {
                seconds := Round(remaining / 1000, 1)
                displayText := skill "`n" seconds " 秒"

                CDHotkeyText[hkName].SetFont(
                    "s10 Norm cFF3030",
                    "Segoe UI"
                )
            }

            CDHotkeyText[hkName].Text := displayText
        }
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
