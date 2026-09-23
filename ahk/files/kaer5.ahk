#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk


; ============================================================
; 基础配置
; ============================================================

global dl := 100

; Alt+D / Alt+F：对自己施法
global alt_d := {key: "d", mods: "!"}
global alt_f := {key: "f", mods: "!"}


; ============================================================
; 技能名称
; ============================================================

global qwwr := "吹风"
global qwer := "推波"
global qqer := "冰墙"

global qeer := "火人"
global wwer := "灵动"
global qqqr := "极冷"
global qqwr := "隐身"

global wwwr := "雷爆"
global eeer := "天火"
global weer := "陨石"


; ============================================================
; 技能列表
; ============================================================

global Skills := [
    qwwr,
    qwer,
    qqer,

    qeer,
    wwer,
    qqqr,
    qqwr,

    wwwr,
    eeer,
    weer
]


; ============================================================
; 技能 CD，单位：毫秒
; ============================================================

global SkillCD := Map(
    qwwr, 27000,
    qqqr, 19000,
    qqer, 23000,
    eeer, 23000,
    weer, 50000,
    qwer, 36000,
    qeer, 27000,
    wwer, 15000,
    wwwr, 27000,
    qqwr, 40000
)


; ============================================================
; 技能上次释放时间
; ============================================================

global SkillLastCast := Map()

for skillName in Skills
    SkillLastCast[skillName] := 0


; ============================================================
; 技能组合映射
; ============================================================

global SkillByCombo := Map(
    "qwwr", qwwr,
    "qwer", qwer,
    "qqer", qqer,

    "qeer", qeer,
    "wwer", wwer,
    "qqqr", qqqr,
    "qqwr", qqwr,

    "wwwr", wwwr,
    "eeer", eeer,
    "weer", weer
)


; ============================================================
; 悬浮窗快捷键布局
;
; 第一行：Q W E
; 第二行：A S D F
; 第三行：Z X C
; ============================================================

global HotkeyLayout := [
    ["q", "w", "e"],
    ["a", "s", "d", "f"],
    ["z", "x", "c"]
]


; ============================================================
; 快捷键对应技能
; ============================================================

global HotkeySkill := Map(
    "q", qwwr,
    "w", qwer,
    "e", qqer,

    "a", qeer,
    "s", wwer,
    "d", qqqr,
    "f", qqwr,

    "z", wwwr,
    "x", eeer,
    "c", weer
)


; ============================================================
; 技能释放组合
;
; 切技能组合本身不包含在这里的逻辑中重复执行。
; 这里保存原始完整组合，用于处理：
;
; - d
; - alt_d
; - dl
; - CapsLock
; - 其他后续操作
; ============================================================

global SkillCastCombo := Map(
    qwwr, ["q", "w", "w", "r", dl, "d"],
    qwer, ["q", "w", "e", "r", dl, "d"],
    qqer, ["q", "q", "e", "r", dl, "d"],

    qeer, [
        "q", "e", "e", "r",
        dl,
        "d",
        dl,
        "a",
        "{CapsLock}",
        "e", "e", "e"
    ],

    wwer, [
        "w", "w", "e", "r",
        dl,
        alt_d,
        "a",
        "e", "e", "e"
    ],

    qqqr, ["q", "q", "q", "r", dl, "d"],
    qqwr, ["q", "q", "w", "r", dl, "d"],

    wwwr, ["w", "w", "w", "r", dl, "d"],
    eeer, ["e", "e", "e", "r", dl, "d"],
    weer, ["w", "e", "e", "r", dl, "d"]
)


; ============================================================
; 当前 D/F 技能槽
; ============================================================

global DSkill := ""
global FSkill := ""


; ============================================================
; 创建 CD 悬浮窗
; ============================================================

global GuiCD := Gui(
    "+AlwaysOnTop -Caption +ToolWindow",
    "技能CD"
)

GuiCD.BackColor := "202020"
GuiCD.MarginX := 8
GuiCD.MarginY := 8

global CDHotkeyText := Map()

global CDCellWidth := 120
global CDCellHeight := 65

; 由于第二行有四个格子，因此按照四格宽度计算
global CDTotalWidth := CDCellWidth * 4

for rowIndex, rowItems in HotkeyLayout {
    rowWidth := rowItems.Length * CDCellWidth

    ; 每一行居中
    rowStartX := 8 + Floor((CDTotalWidth - rowWidth) / 2)
    rowY := 8 + (rowIndex - 1) * CDCellHeight

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
            HotkeySkill[hkName] "`n检测中"
        )

        CDHotkeyText[hkName] := GuiCD[controlName]
    }
}

GuiCD.Show(
    "x20 y200"
    . " w" (CDTotalWidth + 16)
    . " h" (CDCellHeight * 3 + 16)
    . " NoActivate"
)

SetTimer(UpdateCDGui, 100)


; ============================================================
; 输入绑定
; ============================================================

; ------------------------------------------------------------
; Esc：重置槽位状态和 CD 状态
; ------------------------------------------------------------

~Esc::ResetAllState()


; ------------------------------------------------------------
; 单独按 D/F：放当前 D/F 位置上的技能
; ------------------------------------------------------------

$d::CastCurrentSlot("d")
$f::CastCurrentSlot("f")



; ------------------------------------------------------------
; Space 组合：只切技能
;
; Q W E
; A S D F
; Z X C
; ------------------------------------------------------------

~Space & q::SwitchOnlyByCombo(["q", "w", "w", "r"])
~Space & w::SwitchOnlyByCombo(["q", "w", "e", "r"])
~Space & e::SwitchOnlyByCombo(["q", "q", "e", "r"])

~Space & a::SwitchOnlyByCombo(["q", "e", "e", "r"])
~Space & s::SwitchOnlyByCombo(["w", "w", "e", "r"])
~Space & d::SwitchOnlyByCombo(["q", "q", "q", "r"])
~Space & f::SwitchOnlyByCombo(["q", "q", "w", "r"])

~Space & z::SwitchOnlyByCombo(["w", "w", "w", "r"])
~Space & x::SwitchOnlyByCombo(["e", "e", "e", "r"])
~Space & c::SwitchOnlyByCombo(["w", "e", "e", "r"])


; ------------------------------------------------------------
; LAlt 组合：先切技能，再放技能
; ------------------------------------------------------------

LAlt::Return

~LAlt & q::SwitchThenCast(["q", "w", "w", "r"])
~LAlt & w::SwitchThenCast(["q", "w", "e", "r"])
~LAlt & e::SwitchThenCast(["q", "q", "e", "r"])

~LAlt & a::SwitchThenCast(["q", "e", "e", "r"])
~LAlt & s::SwitchThenCast(["w", "w", "e", "r"])
~LAlt & d::SwitchThenCast(["q", "q", "q", "r"])
~LAlt & f::SwitchThenCast(["q", "q", "w", "r"])

~LAlt & z::SwitchThenCast(["w", "w", "w", "r"])
~LAlt & x::SwitchThenCast(["e", "e", "e", "r"])
~LAlt & c::SwitchThenCast(["w", "e", "e", "r"])


; ============================================================
; 根据 q/w/e/r 组合获取技能名称
; ============================================================

GetSkillFromCombo(keys) {
    global SkillByCombo

    combo := ""

    for key in keys
        combo .= key

    if SkillByCombo.Has(combo)
        return SkillByCombo[combo]

    return ""
}


; ============================================================
; 获取技能对应的切换组合
; ============================================================

GetSwitchCombo(skill) {
    global SkillByCombo

    combo := ""

    for comboKey, mappedSkill in SkillByCombo {
        if mappedSkill = skill {
            combo := comboKey
            break
        }
    }

    result := []

    if combo = ""
        return result

    Loop Parse, combo {
        key := A_LoopField

        if key != " "
            result.Push(key)
    }

    return result
}


; ============================================================
; 只切技能
; ============================================================

SwitchOnlyByCombo(keys) {
    skill := GetSkillFromCombo(keys)

    if skill = ""
        return

    SwitchSkillIfNeeded(skill)
}


; ============================================================
; 先切后放
; ============================================================

SwitchThenCast(keys) {
    global DSkill, FSkill

    skill := GetSkillFromCombo(keys)

    if skill = ""
        return

    if !IsSkillReady(skill)
        return

    ; 已经在 D，直接放 D
    if DSkill = skill {
        CastSkill(skill, "d", false)
        return
    }

    ; 已经在 F，直接放 F
    if FSkill = skill {
        CastSkill(skill, "f", false)
        return
    }

    ; 不在 D/F，先切入
    SwitchSkill(skill)

    ; 新技能进入 D。
    ; 切技能已经由 SwitchSkill() 发送，
    ; 这里只发送释放部分，避免重复发送 q/w/e/r。
    CastSkill(skill, "d", false)
}


; ============================================================
; 只切技能时的判断
; ============================================================

SwitchSkillIfNeeded(skill) {
    global DSkill, FSkill

    ; 已经在 D，不需要切
    if DSkill = skill
        return

    ; 已经在 F，重新切到 D
    if FSkill = skill {
        SwitchFToD()
        return
    }

    SwitchSkill(skill)
}


; ============================================================
; 切入技能
; ============================================================

SwitchSkill(skill) {
    global DSkill, FSkill

    if DSkill = skill
        return

    if FSkill = skill {
        SwitchFToD()
        return
    }

    ; D 正在 CD、F 已经可用：
    ; 先把 F 切到 D，防止后续切新技能时把可用技能顶掉
    if DSkill != "" && FSkill != "" {
        if !IsSkillReady(DSkill) && IsSkillReady(FSkill)
            SwitchFToD()
    }

    ; 这里只发送 q/w/e/r
    ; 不发送 d/f
    SendSwitchCommand(skill)

    ; 新技能进入 D
    ; 原 D 进入 F
    ; 原 F 消失
    FSkill := DSkill
    DSkill := skill
}


; ============================================================
; 将 F 技能切到 D
; ============================================================

SwitchFToD() {
    global DSkill, FSkill

    if FSkill = ""
        return

    skill := FSkill
    oldD := DSkill

    ; 只发送切换组合，不释放技能
    SendSwitchCommand(skill)

    ; 槽位交换
    DSkill := skill
    FSkill := oldD
}


; ============================================================
; 发送切技能组合
;
; 只使用 AddCombo。
; 绝不自动添加 d/f。
; ============================================================

SendSwitchCommand(skill) {
    keys := GetSwitchCombo(skill)

    if keys.Length > 0
        AddCombo(keys)
}


; ============================================================
; 单独按 D/F 释放当前槽位
; ============================================================

CastCurrentSlot(position) {
    global DSkill, FSkill

    skill := ""

    if position = "d"
        skill := DSkill
    else if position = "f"
        skill := FSkill
    else
        return

    if skill = ""
        return

    if !IsSkillReady(skill)
        return

    ; 只发送当前槽位按键
    AddCombo([position])

    MarkSkillCast(skill)
}


; ============================================================
; 执行完整技能释放
; ============================================================

CastSkill(skill, position := "d", includeSwitch := false) {
    global SkillCastCombo

    if skill = ""
        return

    if !SkillCastCombo.Has(skill)
        return

    if !IsSkillReady(skill)
        return

    combo := BuildCastCombo(
        SkillCastCombo[skill],
        position,
        includeSwitch
    )

    if combo.Length = 0
        return

    AddCombo(combo)

    MarkSkillCast(skill)
}


; ============================================================
; 根据技能槽生成释放组合
;
; includeSwitch = false：
; 去掉前面的 q/w/e/r 组合，只保留：
;
; - dl
; - d/f
; - alt_d/alt_f
; - CapsLock
; - 其他操作
;
; includeSwitch = true：
; 保留完整组合。
; ============================================================

BuildCastCombo(sourceCombo, position, includeSwitch := false) {
    global alt_d, alt_f

    result := []
    switchFinished := includeSwitch

    for item in sourceCombo {
        ; 只要还没走过切技能部分，就跳过 q/w/e/r，
        ; 直到遇到 r 为止。
        if !switchFinished {
            if Type(item) = "String" && item = "r"
                switchFinished := true

            continue
        }

        ; 普通字符串 d 替换为实际槽位
        if Type(item) = "String" && item = "d" {
            result.Push(position)
            continue
        }

        ; Alt+D 对象替换为实际槽位对应的 Alt+D/Alt+F
        if IsAltDObject(item) {
            if position = "f"
                result.Push(alt_f)
            else
                result.Push(alt_d)

            continue
        }

        ; dl、CapsLock、a、e 等内容原样保留
        result.Push(item)
    }

    return result
}


; ============================================================
; 判断一个队列项是否为 alt_d 对象
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
; ============================================================

IsSkillReady(skill) {
    global SkillCD, SkillLastCast

    if skill = ""
        return false

    if !SkillCD.Has(skill)
        return true

    if !SkillLastCast.Has(skill)
        return true

    elapsed := A_TickCount - SkillLastCast[skill]

    return elapsed >= SkillCD[skill]
}


; ============================================================
; 获取剩余 CD
; ============================================================

GetSkillRemaining(skill) {
    global SkillCD, SkillLastCast

    if skill = ""
        return 0

    if !SkillCD.Has(skill)
        return 0

    if !SkillLastCast.Has(skill)
        return 0

    remaining := SkillCD[skill] - (A_TickCount - SkillLastCast[skill])

    if remaining < 0
        return 0

    return remaining
}


; ============================================================
; 更新 CD 悬浮窗
; ============================================================

UpdateCDGui() {
    global HotkeyLayout
    global HotkeySkill
    global CDHotkeyText
    global DSkill
    global FSkill

    for rowItems in HotkeyLayout {
        for hkName in rowItems {
            if !HotkeySkill.Has(hkName)
                continue

            skill := HotkeySkill[hkName]
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

            if DSkill = skill
                displayText .= " [D]"
            else if FSkill = skill
                displayText .= " [F]"

            CDHotkeyText[hkName].Text := displayText
        }
    }
}
