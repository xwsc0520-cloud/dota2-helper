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

MButton::LAlt
XButton1::LShift

#HotIf

; ============================================================
; 组合键监听器实例
; ============================================================

global listener := 0
KeyR := "F1"
KeyRD := "Space"

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
            256,
            999999,
            SkillHotkeysCondition
        )

        listener.AddB(KeyR, KeyR)
        listener.AddB(KeyRD, KeyRD)

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
    if group = "B" {
        return
    }
    SendInput("{" key " down}")
}


OnSingleUp(group, key, data) {
    if group = "B" {
        return
    }

    ret := false
    if key = "d" || key = "f" {
        ret := CastSlotUp(key)
    }
    if !ret {
        SendInput("{" key " up}")
    }
}

onComboDown(keyA, skill, keyB, dataB){
    if keyB = KeyR {
        SwitchSkill(skill)
    } else if keyB = KeyRD {
        SwitchThenCast(skill)
    }

}

onComboUp(keyA, skill, keyB, dataB){

}
