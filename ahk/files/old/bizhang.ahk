#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\..\common\queue.ahk
#Include %A_ScriptDir%\..\common\OverlapComboListener.ahk

global defaultDelay
defaultDelay := 10

listener := OverlapComboListener(
    OnSingleDown,
    onSingleUp,
    onComboDown,
    onComboUp,
    128,
    999999,
    IsTargetWindow
)

listener.AddB("MButton", "MButton")

listener.AddA("z", "z")
listener.AddA("x", "x")
listener.AddA("c", "c")

listener.Enable()

OnSingleDown(group, key, data) {
    SendInput("{" key " down}")
}

OnSingleUp(group, key, data) {
    SendInput("{" key " up}")
}

onComboDown(keyA, skill, keyB, dataB){
    if keyA = "z" {
        AddCombo(["z", "3", "z", 500, "3", "3"])
    } else if keyA = "x" {
        AddCombo(["z", "3", "x", "z", 500, "3", "3"])
    } else if keyA = "c" {
        AddCombo(["z", "3", "c", "z", 500, "3", "3"])
    }
}

onComboUp(keyA, skill, keyB, dataB){

}

IsTargetWindow(*) {
    return WinActive("ahk_exe notepad.exe")
        || WinActive("ahk_exe dota2.exe")
}