#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk

#HotIf WinActive("ahk_exe notepad.exe")

delay_r := 80
delay_df := 80

q := "q"
w := "w"
e := "e"
r := "r"
d := "d"
f := "f"

~$d::{
    KeyWait("d")
    AddCombo([d])
}

$!q::AddCombo([q, w, e, r])
$!w::AddCombo([e, e, e, r])
$!e::AddCombo([w, w, w, r])

$!a::AddCombo([q, w, w, r])
$!s::AddCombo([q, q, q, r])
$!d::AddCombo([w, e, e, r])

$!z::AddCombo([q, e, e, r])
$!x::AddCombo([w, w, e, r])
$!c::AddCombo([q, q, e, r])
$!v::AddCombo([q, q, w, r])

~Space & q::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, w, e, r])
}
~Space & w::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([e, e, e, r])
}
~Space & e::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([w, w, w, r])
}

~Space & a::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, w, w, r])
}
~Space & s::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, q, q, r])
}
~Space & d::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([w, e, e, r])
}

~Space & z::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, e, e, r])
}
~Space & x::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([w, w, e, r])
}
~Space & c::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, q, e, r])
}
~Space & v::{
    AddCombo([f, delay_df, d, delay_df])
    AddCombo([q, q, w, r])
}
