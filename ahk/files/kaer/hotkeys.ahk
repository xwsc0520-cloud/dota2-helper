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

Up::ChangeHeroLevel(1)
Down::ChangeHeroLevel(-1)

Left::ChangeLinglongxin(false)
Right::ChangeLinglongxin(true)

~Esc::ResetAllState()

#HotIf

; ============================================================
; 组合键监听器实例
; ============================================================

global SkillComboListener := 0


RegisterAllSkillHotkeys() {
    SetAllSkillHotkeys(true)
}


SetAllSkillHotkeys(enabled) {
    global SkillComboListener
    global SkillConfigs

    if !IsObject(SkillComboListener) {
        if !enabled
            return

        listener := OverlapComboListener(
            SkillHotkeysCondition
        )

        ; 监听两个修饰键，逻辑完全相同，
        ; 只是回调函数不同。
        listener.AddModifier(
            "Space",
            OnSpaceSkillCombo
        )

        listener.AddModifier(
            "F1",
            OnAltSkillCombo
        )

        for config in SkillConfigs {
            listener.AddKey(
                config.hotkey,
                OnSingleSkillKey,
                config.name
            )
        }

        SkillComboListener := listener
    }

    if enabled
        SkillComboListener.Enable()
    else
        SkillComboListener.Disable()
}


DisableAllSkillHotkeys() {
    SetAllSkillHotkeys(false)
}


SkillHotkeysCondition(*) {
    global remapEnabled

    return remapEnabled && IsTargetWindow()
}


; 普通单键：只有松开 q 时才执行
OnSingleSkillKey(key, skill) {
    AddCombo([key])
}


; Space + 技能键
OnSpaceSkillCombo(key, skill, modifier) {
    SwitchThenCast(skill)
}


; LAlt + 技能键
OnAltSkillCombo(key, skill, modifier) {
    SwitchOnly(skill)
}
