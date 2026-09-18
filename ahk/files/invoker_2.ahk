#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_ScriptDir%\common.ahk

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
rd := {delay: 100}

gesture.Add(d)
gesture.Add(f)

gesture.Add(w1)
gesture.Add(w2)
gesture.Add(w3)

gesture.Add("Tab")
gesture.Add("LShift")

gesture.Add("q")
gesture.Add("w")
gesture.Add("e")
gesture.Add("r")

gesture.Add("z")
gesture.Add("x")
gesture.Add("c")
gesture.Add("v")

OnSingle(key)
{
    switch key
    {
        case d:
            AddCombo([d])
        case f:
            AddCombo([f])

        case w1:
            AddCombo([w1])
        case w2:
            AddCombo([w2])
        case w3:
            AddCombo([w3])

        case "Tab":
            AddCombo([w, w, w, r])
        case "LShift":
            AddCombo([q, q, w, r, rd, d])

        case "q":
            AddCombo([q, q, q, r])
        case "w":
            AddCombo([q, w, w, r])
        case "e":
            AddCombo([q, q, e, r])
        case "r":
            AddCombo([q, w, e, r])

        case "z":
            AddCombo([e, e, e, r])
        case "x":
            AddCombo([w, e, e, r])
        case "c":
            AddCombo([w, w, e, r])
        case "v":
            AddCombo([q, e, e, r])

    }
}

OnDouble(key)
{
    switch key
    {
        case d:
            AddCombo([d, d])
        case f:
            AddCombo([f, f])

        case "Tab":
            AddCombo([q, w, w, r, rd, d, rd, f])

        case "q":
            AddCombo([w, e, e, r, rd, f, rd, d])

        case "w":
            AddCombo([e, e, e, r, rd, f, rd, d])

        case "e":
            AddCombo([q, q, q, r, rd, f, rd, d])

        case "r":
            AddCombo([w, e, e, r, rd, d, rd, f])


        case "z":
            AddCombo([q, w, w, r, rd, d, rd, f])

        case "x":
            AddCombo([q, w, e, r, rd, f, rd, d])

        case "c":
            AddCombo([q, e, e, r, rd, alt_f, rd, d])

        case "v":
            AddCombo([w, w, e, r, rd, f, rd, alt_d])

    }
}

OnTriple(key)
{
    switch key
    {
        case "Tab":


        case "q":


        case "w":


        case "e":


        case "r":


        case "z":
            AddCombo(["1", f, rd, d, rd])
            AddCombo([q, w, e, r])
        case "x":

        case "c":

        case "v":


    }
}

OnLong(key, duration)
{
    switch key
    {
        case "q":
            AddCombo([q, q, q])
        case "w":
            AddCombo([w, w, w])
        case "e":
            AddCombo([e, e, e])
    }
}

gesture.OnSingle := OnSingle
gesture.OnDouble := OnDouble
gesture.onTriple := onTriple
gesture.OnLong := OnLong