global GuiCD := ""
global DSlotText := ""
global FSlotText := ""
global HeroLevelText := ""
global RCDText := ""
global CDHotkeyText := Map()
global GSIClockText

global UiRReady := false

CreateCDGui() {
    global GuiCD
    global DSlotText
    global FSlotText
    global HeroLevelText
    global RCDText
    global CDHotkeyText

    global CDTotalWidth
    global SlotRowHeight
    global CDCellWidth
    global CDCellHeight
    global CDWindowWidth
    global CDWindowHeight
    global GUI_TRANSPARENCY
    global HotkeyLayout
    global SkillByHotkey

    GuiCD := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20",
        "技能CD"
    )

    GuiCD.BackColor := "202020"
    GuiCD.MarginX := 4
    GuiCD.MarginY := 4

    SlotRowHeight := 18
    CDCellHeight  := 22
    lineH         := 16

    GuiCD.SetFont("s11 Bold cFFFFFF", "Segoe UI")

    halfWidth := Floor(CDTotalWidth / 2)

    DSlotText := GuiCD.AddText(
        "x4 y4 w" halfWidth " h" SlotRowHeight " Center +0x200",
        "D槽：未同步"
    )

    FSlotText := GuiCD.AddText(
        "x" (4 + halfWidth)
        . " y4 w" halfWidth
        . " h" SlotRowHeight
        . " Center +0x200",
        "F槽：未同步"
    )

    row2Y := 4 + SlotRowHeight

    HeroLevelText := GuiCD.AddText(
        "x4 y" row2Y " w" halfWidth " h" lineH " Center +0x200",
        "等级：1"
    )

    RCDText := GuiCD.AddText(
        "x" (4 + halfWidth)
        . " y" row2Y
        . " w" halfWidth
        . " h" lineH
        . " Center +0x200",
        "R：就绪"
    )

    gridY := row2Y + lineH + 1

    for rowIndex, rowItems in HotkeyLayout {
        rowY := gridY + (rowIndex - 1) * CDCellHeight

        for colIndex, hkName in rowItems {
            cellX := 4 + (colIndex - 1) * CDCellWidth
            controlName := "CD_" hkName

            GuiCD.SetFont("s8 Norm cFFFFFF", "Segoe UI")

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

    rows := HotkeyLayout.Length
    CDWindowHeight := gridY + rows * CDCellHeight + 4
    CDWindowWidth  := 4 + CDTotalWidth + 4

    GuiCD.Show(
        "w" CDWindowWidth
        . " h" CDWindowHeight
        . " NoActivate"
    )

    ; 屏幕底部居中，向上偏移一点
    offsetUp := 150
    posX := Round((A_ScreenWidth - CDWindowWidth) / 2)
    posY := A_ScreenHeight - CDWindowHeight - offsetUp
    WinMove(posX, posY, , , "ahk_id " GuiCD.Hwnd)

    WinSetTransparent(
        GUI_TRANSPARENCY,
        "ahk_id " GuiCD.Hwnd
    )
}


UpdateCDGui() {
    global DSkill
    global FSkill
    global DSlotText
    global FSlotText
    global HotkeyLayout
    global SkillByHotkey
    global CDHotkeyText
    global HeroLevel
    global HeroLevelText
    global RCDText
    global UiRReady

    UpdateSlotText(DSlotText, "D", DSkill)
    UpdateSlotText(FSlotText, "F", FSkill)

    for rowItems in HotkeyLayout {
        for hkName in rowItems {
            if !SkillByHotkey.Has(hkName)
                continue

            skill := SkillByHotkey[hkName]
            remaining := GetSkillRemaining(skill)
            control := CDHotkeyText[hkName]
            isInSlot := skill = DSkill || skill = FSkill

            if remaining <= 0 {
                control.Text := skill

                if isInSlot {
                    control.SetFont(
                        "s9 Bold c30FF30",
                        "Arial Black"
                    )
                } else if IsRReady() {
                    control.SetFont(
                        "s8 Norm c8080FF",
                        "Segoe UI"
                    )
                } else {
                    control.SetFont(
                        "s8 Norm cFFFFFF",
                        "Segoe UI"
                    )
                }
            } else {
                control.Text := skill " " Round(remaining / 1000, 1) "秒"

                control.SetFont(
                    "s8 Norm cFF3030",
                    "Segoe UI"
                )
            }
        }
    }

    HeroLevelText.Text := "等级：" HeroLevel

    rRemaining := GetRRemaining()

    if rRemaining <= 0 {
        RCDText.Text := "R：就绪"
        RCDText.SetFont(
            "s8 Bold c00FF00",
            "Segoe UI"
        )
        if !UiRReady {
            SoundSkillReadyAsync()
            UiRReady := true
        }
    } else {
        RCDText.Text :=
            "R：" Round(rRemaining / 1000, 1) "秒"

        RCDText.SetFont(
            "s8 Bold cFF3030",
            "Segoe UI"
        )
        UiRReady := false
    }
}


FormatGameTime(seconds) {
    seconds := Integer(seconds)

    sign := ""

    if seconds < 0 {
        sign := "-"
        seconds := Abs(seconds)
    }

    minutes := Floor(seconds / 60)
    remainSeconds := Mod(seconds, 60)

    return sign Format("{:02}:{:02}", minutes, remainSeconds)
}


UpdateSlotText(control, slotName, skill) {
    global SkillByName

    if skill = "" {
        control.Text := slotName "槽：未同步"
        control.SetFont("s13 Bold cAAAAAA", "Segoe UI")
        return
    }

    hotkey := StrUpper(SkillByName[skill].hotkey)
    control.Text := slotName "槽：" skill " " hotkey

    if GetSkillRemaining(skill) <= 0
        control.SetFont("s13 Bold c00FF00", "Segoe UI")
    else
        control.SetFont("s13 Bold cFF3030", "Segoe UI")
}

ShowCDGui() {
    global GuiCD
    GuiCD.Show("NoActivate")
}

HideCDGui() {
    global GuiCD
    GuiCD.Hide()
}

SoundSkillReadyAsync()
{
    SetTimer(() => SoundSkillReady(), -1)
}

SoundSkillReady()
{
    SoundBeep(660, 80)
    Sleep(35)
    SoundBeep(990, 120)
}