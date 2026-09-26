; ===== 全局开关 =====
global remapEnabled := true

IsTargetWindow() {
    return WinActive("ahk_exe notepad.exe")
        || WinActive("ahk_exe dota2.exe")
}

#SuspendExempt
F12:: {
    global remapEnabled
    remapEnabled := !remapEnabled

    if remapEnabled {
        SetAllSkillHotkeys(true)
        Suspend(false)
        ShowCDGui()
    } else {
        SetAllSkillHotkeys(false)
        Suspend(true)
        HideCDGui()
    }
}
#SuspendExempt False

#HotIf IsTargetWindow()

LShift::F1
LAlt::F2
LWin::F3

Up::ChangeHeroLevel(1)
Down::ChangeHeroLevel(-1)

Left::ChangeLinglongxin(false)
Right::ChangeLinglongxin(true)

~Esc::ResetAllState()

$d::CastCurrentSlot("d")
$f::CastCurrentSlot("f")

#HotIf

RegisterAllSkillHotkeys() {
    SetAllSkillHotkeys(true)
}

SetAllSkillHotkeys(enabled) {
    global SkillConfigs

    for config in SkillConfigs {
        if enabled {
            RegisterOneSkillHotkey(config)
        } else {
            Hotkey("Space & " config.hotkey, "Off")
            Hotkey("LAlt & " config.hotkey, "Off")
        }
    }
}

RegisterOneSkillHotkey(config) {
    skill := config.name
    hk := config.hotkey

    Hotkey("Space & " hk, (*) => SwitchThenCast(skill), "On")
    Hotkey("LAlt & " hk, (*) => SwitchOnly(skill), "On")
}
