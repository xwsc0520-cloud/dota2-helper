#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\..\common\queue.ahk
#Include %A_ScriptDir%\..\common\OverlapComboListener.ahk

global defaultDelay
defaultDelay := 10

listener := OverlapComboListener(IsTargetWindow)

listener.AddModifier("Space", OnSpaceSkillCombo)

listener.AddKey("z", OnSingleSkillKey)
listener.AddKey("x", OnSingleSkillKey)
listener.AddKey("c", OnSingleSkillKey)

listener.Enable()

OnSpaceSkillCombo(key, skill, modifier) {
    if key = "z" {
        AddCombo(["z", "3", "z", 500, "3", "3"])
    } else if key = "x" {
        AddCombo(["z", "3", "x", "z", 500, "3", "3"])
    } else if key = "c" {
        AddCombo(["z", "3", "c", "z", 500, "3", "3"])
    }
}

OnSingleSkillKey(key, skill) {
     AddCombo([key])
}

IsTargetWindow(*) {
    return WinActive("ahk_exe notepad.exe")
        || WinActive("ahk_exe dota2.exe")
}