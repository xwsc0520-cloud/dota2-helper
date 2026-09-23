#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk

dl := 100

q := "q"
w := "w"
e := "e"
r := "r"
f := "f"
d := "d"

alt_d := {key: d, mods: "!"}

$d::AddCombo([d])
$f::AddCombo([f])

~Space & q::AddCombo([q, w, w, r])
~Space & w::AddCombo([q, q, q, r])
~Space & e::AddCombo([q, q, e, r])
~Space & z::AddCombo([e, e, e, r])
~Space & x::AddCombo([w, e, e, r])
~Space & c::AddCombo([q, w, e, r])
~Space & a::AddCombo([q, e, e, r])
~Space & s::AddCombo([w, w, e, r,])
~Space & d::AddCombo([w, w, w, r])
~Space & f::AddCombo([q, q, w, r])

LAlt::Return
~LAlt & q::AddCombo([q, w, w, r, dl, d])
~LAlt & w::AddCombo([q, q, q, r, dl, d])
~LAlt & e::AddCombo([q, q, e, r, dl, d])
~LAlt & z::AddCombo([e, e, e, r, dl, d])
~LAlt & x::AddCombo([w, e, e, r, dl, d])
~LAlt & c::AddCombo([q, w, e, r, dl, d])
~LAlt & a::AddCombo([q, e, e, r, dl, d, dl, "a", "{CapsLock}"])
~LAlt & s::AddCombo([w, w, e, r, dl, alt_d, dl, "a"])
~LAlt & d::AddCombo([w, w, w, r, dl, d])
~LAlt & f::AddCombo([q, q, w, r, dl, d])




