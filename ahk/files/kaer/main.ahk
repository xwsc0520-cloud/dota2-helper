#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\..\common\queue.ahk

#Include %A_ScriptDir%\config.ahk
#Include %A_ScriptDir%\state.ahk
#Include %A_ScriptDir%\skills.ahk
#Include %A_ScriptDir%\ui.ahk
#Include %A_ScriptDir%\hotkeys.ahk
#Include %A_ScriptDir%\gsi.ahk

InitSkillState()
CreateCDGui()
RegisterAllSkillHotkeys()
StartGSI()

SetTimer(UpdateCDGui, 100)
