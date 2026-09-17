#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetNumLockState("AlwaysOn")
SetCapsLockState("Off")
SetWorkingDir(A_ScriptDir)

SetTitleMatchMode(2)
DetectHiddenWindows(true)

delayTime := 40

orbQ := "{F1}"
orbW := "{F2}"
orbE := "{F3}"
invokeKey := "{F4}"

;orbQ := "1"
;orbW := "2"
;orbE := "3"
;invokeKey := "4"

comboQueue := []
queueRunning := false

$d::AddCombo(["d"])
$f::AddCombo(["f"])

$1::AddCombo(["1"])
$2::AddCombo(["2"])
$3::AddCombo(["3"])


$q::
{
    global orbQ, invokeKey

    AddCombo([
        orbQ,
        orbQ,
        orbQ,
        invokeKey
    ])
}

$w::
{
    global orbQ, orbW, invokeKey

    AddCombo([
        orbQ,
        orbW,
        orbW,
        invokeKey
    ])
}

$e::
{
    global orbQ, orbE, invokeKey

    AddCombo([
        orbQ,
        orbQ,
        orbE,
        invokeKey
    ])
}

$r::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbQ,
        orbW,
        orbE,
        invokeKey
    ])
}

$z::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbE,
        orbE,
        orbE,
        invokeKey
    ])
}

$x::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbW,
        orbE,
        orbE,
        invokeKey
    ])
}

$c::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbW,
        orbW,
        orbE,
        invokeKey
    ])
}

$v::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbQ,
        orbE,
        orbE,
        invokeKey,
        "d"
    ])
}

$Tab::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbW,
        orbW,
        orbW,
        invokeKey
    ])
}

$LShift::
{
    global orbQ, orbW, orbE, invokeKey

    AddCombo([
        orbQ,
        orbQ,
        orbW,
        invokeKey,
        "d"
    ])
}



; 将一个完整组合添加到队列
AddCombo(combo)
{
    global comboQueue, queueRunning

    comboQueue.Push(combo)

    if !queueRunning {
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
}

; 按加入顺序处理队列
ProcessComboQueue()
{
    global comboQueue, queueRunning, delayTime

    while comboQueue.Length > 0 {
        combo := comboQueue.RemoveAt(1)

        for index, key in combo {
            SendInput(key)

            ; 最后一个键之后不延时
            if index < combo.Length
                randomDelay(delayTime)
        }
    }

    queueRunning := false

    ; 防止恰好在 queueRunning 关闭时又有新组合加入
    if comboQueue.Length > 0 {
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
}

; 随机延时
randomDelay(baseTime)
{
    minTime := Round(baseTime * 0.9)
    maxTime := Round(baseTime * 1.1)
    actualTime := Random(minTime, maxTime)

    Sleep(actualTime)
}