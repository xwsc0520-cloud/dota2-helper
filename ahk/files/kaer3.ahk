#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk

#HotIf WinActive("ahk_exe notepad.exe")

delay_r := 100

q := "q"
w := "w"
e := "e"
r := "r"
f := "f"
d := "v"

alt_d := {key: d, mods: "!"}

$d::AddCombo([d])
$f::AddCombo([f])

LAlt::Return

LAlt & q::AddCombo([q, w, e, r])
LAlt & w::AddCombo([e, e, e, r])
LAlt & e::AddCombo([q, q, e, r])

LAlt & a::AddCombo([q, w, w, r])
LAlt & s::AddCombo([q, q, q, r])
LAlt & d::AddCombo([w, e, e, r])
LAlt & f::AddCombo([q, q, w, r, delay_r, d])

LAlt & z::AddCombo([q, e, e, r, delay_r, d])
LAlt & x::AddCombo([w, w, e, r, delay_r, d])
LAlt & c::AddCombo([w, w, w, r])


LShift & w::AddCombo([e, e, e, r, delay_r, alt_d])