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

        ResetAllState()
        CancelComboQueue()
    }
}
#SuspendExempt False

#HotIf IsTargetWindow()

Up::ChangeHeroLevel(1)
Down::ChangeHeroLevel(-1)

Left::ChangeLinglongxin(false)
Right::ChangeLinglongxin(true)

#HotIf

; ============================================================
; 组合键监听器实例
; ============================================================

global listener := 0

RegisterAllSkillHotkeys() {
    SetAllSkillHotkeys(true)
}

SetAllSkillHotkeys(enabled) {
    global listener
    global SkillConfigs

    if !IsObject(listener) {
        if !enabled
            return

        listener := OverlapComboListener(
            OnSingleDown,
            onSingleUp,
            onComboDown,
            onComboUp,
            128,
            SkillHotkeysCondition
        )

        listener.AddB("F1", "F1")
        listener.AddB("Space", "Space")

        for config in SkillConfigs {
            listener.AddA(config.hotkey, config.name)
        }

    }

    if enabled
        listener.Enable()
    else
        listener.Disable()
}


DisableAllSkillHotkeys() {
    SetAllSkillHotkeys(false)
}


SkillHotkeysCondition(*) {
    global remapEnabled
    return remapEnabled && IsTargetWindow()
}

OnSingleDown(group, key, data) {
    if group = "B"
        return

    if key = "d" || key = "f" {
        SendInput("{" key " down}")
        return
    }

    AddCombo([key])
}


OnSingleUp(group, key, data) {
    if group = "A" && (key = "d" || key = "f") {
        SendInput("{" key " up}")
    }
}

onComboDown(keyA, skill, keyB, dataB){
    if keyB = "F1" {
        SwitchSkill(skill)
    } else if keyB = "Space" {
        SwitchThenCast(skill)
    }

}

onComboUp(keyA, skill, keyB, dataB){

}
