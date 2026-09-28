#Requires AutoHotkey v2.0

global defaultDelay := 50
global comboQueue := []
global queueRunning := false
global queueCancel := false

; 记录需要取消的按键。
; Map 的键为规范化后的按键名称，例如 "d"、"enter"、"lalt"。
global cancelledKeys := Map()


; =========================
; 取消当前队列
; =========================
CancelComboQueue()
{
    global comboQueue, queueRunning, queueCancel, cancelledKeys

    comboQueue := []
    cancelledKeys.Clear()
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
; 取消尚未发送的指定按键
;
; 示例：
;   CancelQueuedKey("d")
;   CancelQueuedKey("{d}")
;   CancelQueuedKey("{d down}")
;   CancelQueuedKey("{Enter}")
;
; down、up 和 {Blind} 不影响匹配。
; 已经调用 SendEvent 发送的按键不会被撤销。
; =========================
CancelQueuedKey(key)
{
    global comboQueue, cancelledKeys

    keyName := NormalizeKeyName(key)

    ; 确保已经从全局队列取出的当前组合也能被过滤。
    cancelledKeys[keyName] := true

    ; 立即删除全局队列中尚未取出的匹配动作。
    for combo in comboQueue {
        index := combo.Length

        while index >= 1 {
            action := combo[index]

            if action.type = "send"
                && action.keyName = keyName {
                combo.RemoveAt(index)
            }

            index--
        }
    }
}


; =========================
; 将按键格式规范化为按键名称
;
; 以下格式都会得到 "d"：
;   "d"
;   "{d}"
;   "{d down}"
;   "{d up}"
;   "{Blind}d"
;   "{Blind}{d down}"
; =========================
NormalizeKeyName(key)
{
    if Type(key) != "String"
        throw TypeError(
            "NormalizeKeyName(): key 必须是字符串"
        )

    if key = ""
        throw ValueError(
            "NormalizeKeyName(): key 不能为空"
        )

    value := key

    ; 去掉内部发送值可能带有的 {Blind} 前缀。
    if RegExMatch(value, "i)^\{Blind\}", &blindMatch)
        value := SubStr(value, StrLen(blindMatch[0]) + 1)

    ; 普通单字符，例如 d、1、?
    if StrLen(value) = 1
        return StrLower(value)

    ; 显式 AHK 按键格式：
    ; {Key}
    ; {Key down}
    ; {Key up}
    if !RegExMatch(
        value,
        "i)^\{([A-Za-z][A-Za-z0-9]*)(?:\s+(?:down|up))?\}$",
        &match
    ) {
        throw ValueError(
            "NormalizeKeyName(): 无效的单个按键：" key
        )
    }

    keyName := match[1]

    if StrLen(keyName) > 1 && !IsAllowedKeyName(keyName)
        throw ValueError(
            "NormalizeKeyName(): 不允许的按键名称：" keyName
        )

    return StrLower(keyName)
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
    global cancelledKeys

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
        ; 新一轮队列开始时，清除上一轮的按键取消记录。
        cancelledKeys.Clear()
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
            value: "{Blind}" item,
            keyName: NormalizeKeyName(item)
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

    if StrLen(keyName) = 1
        return

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

    ; Map 的字符串键默认区分大小写，因此逐项忽略大小写比较。
    for allowedName in allowedNames {
        if StrLower(allowedName) = StrLower(keyName)
            return true
    }

    return false
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
    global cancelledKeys

    try {
        while comboQueue.Length > 0 && !queueCancel {
            combo := comboQueue.RemoveAt(1)

            for action in combo {
                if queueCancel
                    break

                switch action.type {
                    case "send":
                        ; 在真正发送前检查，因此已取出但尚未发送的
                        ; 当前组合动作也可以被取消。
                        if cancelledKeys.Has(action.keyName)
                            continue

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
            cancelledKeys.Clear()
            queueCancel := false
        }
        else if comboQueue.Length > 0 {
            queueRunning := true
            SetTimer(ProcessComboQueue, -1)
        }
        else {
            ; 本轮队列已执行完毕，取消状态不延续到下一轮。
            cancelledKeys.Clear()
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
