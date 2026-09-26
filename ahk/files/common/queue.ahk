#Requires AutoHotkey v2.0

global defaultDelay := 50
global comboQueue := []
global queueRunning := false
global queueCancel := false


; =========================
; 取消当前队列
; =========================
CancelComboQueue()
{
    global comboQueue, queueRunning, queueCancel

    comboQueue := []
    queueCancel := true

    ; 防止修饰键残留
    SendEvent "{LAlt up}"
    SendEvent "{RAlt up}"
    SendEvent "{LCtrl up}"
    SendEvent "{RCtrl up}"
    SendEvent "{LShift up}"
    SendEvent "{RShift up}"
    SendEvent "{LWin up}"
    SendEvent "{RWin up}"

    if !queueRunning
        queueCancel := false
}


; =========================
; 添加一个按键/延迟序列
;
; 字符串：按键
; 数字：延迟毫秒数
; =========================
AddCombo(combo)
{
    global comboQueue, queueRunning, queueCancel

    if !IsObject(combo)
        throw TypeError(
            "AddCombo(): combo 必须是数组或其他可枚举对象"
        )

    actions := []

    for index, item in combo {
        action := ParseComboItem(item, index)
        actions.Push(action)
    }

    if actions.Length = 0
        throw ValueError(
            "AddCombo(): combo 不能为空"
        )

    comboQueue.Push(actions)

    if !queueRunning {
        queueCancel := false
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
}


; =========================
; 解析输入项
; =========================
ParseComboItem(item, index)
{
    itemType := Type(item)

    ; 字符串：按键
    if itemType = "String" {
        ValidateKeyString(item, index)

        return {
            type: "send",
            value: "{Blind}" item
        }
    }

    ; 整数或小数：延迟
    if itemType = "Integer" || itemType = "Float" {
        ValidateDelay(item, index)

        return {
            type: "delay",
            value: item
        }
    }

    throw TypeError(
        "combo[" index "]: 只允许字符串按键或数字延迟"
    )
}


; =========================
; 验证按键字符串
;
; 允许：
;   "a"
;   "1"
;   "{Enter}"
;   "{F2}"
;   "{LAlt down}"
;   "{LAlt up}"
; =========================
ValidateKeyString(key, index)
{
    if key = ""
        throw ValueError(
            "combo[" index "]: 按键不能为空"
        )

    ; 普通单字符，例如 a、1、?
    if StrLen(key) = 1
        return

    ; 显式 AHK 按键格式
    if !RegExMatch(key, "^\{([^{}]+)\}$", &match)
        throw ValueError(
            "combo[" index "]: " key
            " 不是有效的单个按键"
        )

    token := match[1]

    ; 允许：
    ; {Key}
    ; {Key down}
    ; {Key up}
    if !RegExMatch(
        token,
        "i)^([A-Za-z][A-Za-z0-9]*)(?:\s+(down|up))?$",
        &parts
    ) {
        throw ValueError(
            "combo[" index "]: 无效的按键格式：" key
        )
    }

    keyName := parts[1]

    if !IsAllowedKeyName(keyName)
        throw ValueError(
            "combo[" index "]: 不允许的按键名称：" keyName
        )
}


; =========================
; 判断是否为允许的按键名称
; =========================
IsAllowedKeyName(keyName)
{
    static allowedNames := Map(
        "LButton", true,
        "RButton", true,
        "MButton", true,
        "XButton1", true,
        "XButton2", true,

        "Backspace", true,
        "Tab", true,
        "Enter", true,
        "Esc", true,
        "Space", true,
        "Delete", true,
        "Insert", true,
        "Home", true,
        "End", true,
        "PgUp", true,
        "PgDn", true,

        "Up", true,
        "Down", true,
        "Left", true,
        "Right", true,

        "PrintScreen", true,
        "Pause", true,
        "AppsKey", true,

        "CapsLock", true,

        "LAlt", true,
        "RAlt", true,
        "LCtrl", true,
        "RCtrl", true,
        "LShift", true,
        "RShift", true,
        "LWin", true,
        "RWin", true,

        "NumpadAdd", true,
        "NumpadSub", true,
        "NumpadMult", true,
        "NumpadDiv", true,
        "NumpadDot", true,
        "NumpadEnter", true
    )

    ; F1-F24
    if RegExMatch(keyName, "i)^F([1-9]|1[0-9]|2[0-4])$")
        return true

    ; Numpad0-Numpad9
    if RegExMatch(keyName, "i)^Numpad[0-9]$")
        return true

    return allowedNames.Has(keyName)
}


; =========================
; 验证延迟
; =========================
ValidateDelay(value, index)
{
    valueType := Type(value)

    if valueType != "Integer" && valueType != "Float"
        throw TypeError(
            "combo[" index "]: 延迟必须是数字"
        )

    if value < 0
        throw ValueError(
            "combo[" index "]: 延迟不能小于 0"
        )
}


; =========================
; 执行队列
; =========================
ProcessComboQueue()
{
    global comboQueue, queueRunning, queueCancel

    try {
        while comboQueue.Length > 0 && !queueCancel {
            combo := comboQueue.RemoveAt(1)

            for action in combo {
                if queueCancel
                    break

                switch action.type {
                    case "send":
                        SendEvent(action.value)
                        RandomDelay(defaultDelay)

                    case "delay":
                        RandomDelay(action.value)
                }
            }
        }
    }
    finally {
        queueRunning := false

        if queueCancel {
            comboQueue := []
            queueCancel := false
        }
        else if comboQueue.Length > 0 {
            queueRunning := true
            SetTimer(ProcessComboQueue, -1)
        }
    }
}


; =========================
; 随机延迟
; 实际延迟为 baseTime 的 85%~115%
; =========================
RandomDelay(baseTime)
{
    global queueCancel

    minTime := Max(0, Round(baseTime * 0.85))
    maxTime := Max(minTime, Round(baseTime * 1.15))
    targetTime := Random(minTime, maxTime)

    startTime := A_TickCount

    while !queueCancel {
        elapsed := A_TickCount - startTime
        remaining := targetTime - elapsed

        if remaining <= 0
            break

        Sleep(Min(5, remaining))
    }
}
