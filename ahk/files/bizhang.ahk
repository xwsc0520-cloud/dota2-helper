#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk


d := {delay: 50}

!z:: {
    KeyWait("LAlt")
    KeyWait("z")

    AddCombo(["z", "z"])
}

!x:: {
    KeyWait("LAlt")
    KeyWait("x")

    AddCombo(["z", "x", "z"])
}

!c:: {
    KeyWait("LAlt")
    KeyWait("c")

    AddCombo(["z", "c", "z"])
}