#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk

; 单独按下并松开 Space 时，正常输入空格
Space::SendInput("{Space}")

; 按住 Space，再按 Q/W/E
Space & q::SendInput("qqq")
Space & w::SendInput("www")
Space & e::SendInput("eee")
