global GuiCD := ""
global DSlotText := ""
global FSlotText := ""
global HeroLevelText := ""
global RCDText := ""
global CDHotkeyText := Map()
global GSIClockText

CreateCDGui() {
    global GuiCD
    global DSlotText
    global FSlotText
    global HeroLevelText
    global RCDText
    global GSIClockText
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
    GuiCD.MarginX := 8
    GuiCD.MarginY := 8

    GuiCD.SetFont("s13 Bold cFFFFFF", "Segoe UI")

    halfWidth := Floor(CDTotalWidth / 2)

    DSlotText := GuiCD.AddText(
        "x8 y8 w" halfWidth " h" SlotRowHeight " Center",
        "D槽：未同步"
    )

    FSlotText := GuiCD.AddText(
        "x" (8 + halfWidth)
        . " y8 w" halfWidth
        . " h" SlotRowHeight
        . " Center",
        "F槽：未同步"
    )

    HeroLevelText := GuiCD.AddText(
        "x8 y42 w" halfWidth " h20 Center",
        "等级：1"
    )

    RCDText := GuiCD.AddText(
        "x" (8 + halfWidth)
        . " y42 w" halfWidth
        . " h20 Center",
        "R：就绪"
    )

    ; 游戏时间
    GSIClockText := GuiCD.AddText(
        "x8 y62 w" CDTotalWidth " h30 Center",
        "游戏时间：未同步"
    )
    GSIClockText.Visible := false

    for rowIndex, rowItems in HotkeyLayout {
        rowY := 8 + SlotRowHeight + 18 + (rowIndex - 1) * CDCellHeight

        for colIndex, hkName in rowItems {
            cellX := 8 + (colIndex - 1) * CDCellWidth
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

    GuiCD.Show(
        "x20 y200"
        . " w" CDWindowWidth
        . " h" (CDWindowHeight + 18)
        . " NoActivate"
    )

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

    global GSIClockText
    global GSIDataReady
    global GSIClockTime
    global HeroLevel

    if GSIDataReady {
        GSIClockText.Text :=
            "游戏时间：" FormatGameTime(GSIClockTime)
    } else {
        GSIClockText.Text := "游戏时间：未同步"
    }

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
                        "s11 Bold c30FF30",
                        "Arial Black"
                    )
                } else if IsRReady() {
                    control.SetFont(
                        "s10 Norm c8080FF",
                        "Segoe UI"
                    )
                } else {
                    control.SetFont(
                        "s10 Norm cFFFFFF",
                        "Segoe UI"
                    )
                }
            } else {
                control.Text := skill " " Round(remaining / 1000, 1) "秒"

                control.SetFont(
                    "s10 Norm cFF3030",
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
            "s10 Bold c00FF00",
            "Segoe UI"
        )
    } else {
        RCDText.Text :=
            "R：" Round(rRemaining / 1000, 1) "秒"

        RCDText.SetFont(
            "s10 Bold cFF3030",
            "Segoe UI"
        )
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
