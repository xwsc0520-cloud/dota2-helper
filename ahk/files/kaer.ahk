#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

#Include %A_ScriptDir%\queue.ahk

q := "7"
w := "8"
e := "9"
r := "0"
d := "d"
f := "f"
w1 := "1"
w2 := "2"
w3 := "3"

alt_d := "!d"
alt_f := "!f"
delay_r := 80
delay_df := 80

$d::AddCombo([d])
$f::AddCombo([f])
$1::AddCombo([w1])
$2::AddCombo([w2])
$3::AddCombo([w3])

$Tab::AddCombo([w, w, w, r])
$LShift::AddCombo([q, q, w, r])

$q::{
    if GetKeyState("Space", "P") {
        KeyWait("Space")
        KeyWait("q")
        AddCombo(["q", "q", "q"])
    } else {
        AddCombo([q, q, q, r])
    }
}
$*w::{
    if GetKeyState("LAlt", "P") {
        return
    }
    if GetKeyState("Space", "P") {
        KeyWait("Space")
        KeyWait("w")
        AddCombo(["w", "w", "w"])
    } else {
        AddCombo([q, w, w, r])
    }
}
$e::{
    if GetKeyState("Space", "P") {
        KeyWait("Space")
        KeyWait("e")
        AddCombo(["e", "e", "e"])
    } else {
        AddCombo([q, q, e, r])
    }
}

$r::AddCombo([q, w, e, r])
$z::AddCombo([e, e, e, r])
$x::AddCombo([w, e, e, r])
$c::AddCombo([w, w, e, r, delay_r, alt_d])
$v::AddCombo([q, e, e, r, delay_r, d])

; 四段式连招
$!w:: {
    KeyWait("Alt")
    KeyWait("w")
    AddCombo([d, delay_df, f, delay_df])
    AddCombo([w, e, e, r, delay_r])
}
$!x:: {
    KeyWait("Alt")
    KeyWait("x")
    AddCombo([d, delay_df, w1, delay_df])
    AddCombo([e, e, e])
}
; 三段自己：切r(qwe) + 等大
$!z:: {
    KeyWait("Alt")
    KeyWait("z")
    AddCombo([d, delay_df])
    AddCombo([e, e, e, r, delay_r])
}



; 三段式连招
$!q:: {
    KeyWait("Alt")
    KeyWait("q")
    AddCombo([d, delay_df, f, delay_df])
    AddCombo([w, w, w, r, delay_r])
    AddCombo([q, q, e, r, delay_r])
    AddCombo([d, delay_df, f, delay_df])
    AddCombo([w, e, e, r, delay_r])
}
$!c:: {
    KeyWait("Alt")
    KeyWait("c")
    AddCombo([d, delay_df, w1, delay_df])
    AddCombo([q, w, e, r, delay_r])
    AddCombo([e, e, e, r, delay_r])
}
; 三段自己：f + d