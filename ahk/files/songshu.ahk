#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk


d := {delay: 50}

Space:: {
    AddCombo([" "])
}

Space & e:: {
    KeyWait("Space")
    KeyWait("e")

    AddCombo(["r", d, "q", d, "1", {delay: 200}, "2", d, "w", d, "f",  {delay: 2500}, "r"])
}
