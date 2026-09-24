global defaultDelay := 30
global comboQueue := []
global queueRunning := false
global queueCancel := false

; ~Esc::CancelComboQueue()


CancelComboQueue()
{
    global comboQueue, queueRunning, queueCancel

    comboQueue := []
    queueCancel := true

    if !queueRunning
        queueCancel := false
}


AddCombo(combo)
{
    global comboQueue, queueRunning, queueCancel

    if !IsObject(combo)
        throw TypeError("AddCombo(): combo 必须是数组或其他可枚举对象")

    actions := []

    for index, item in combo {
        action := ParseComboItem(item, index)
        actions.Push(action)
    }

    if actions.Length = 0
        throw ValueError("AddCombo(): combo 不能为空")

    comboQueue.Push(actions)

    if !queueRunning {
        queueCancel := false
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
}


ParseComboItem(item, index)
{
    ; 延迟对象或组合键对象
    if IsObject(item) {
        hasKey := item.HasOwnProp("key")
        hasMods := item.HasOwnProp("mods")
        hasDelay := item.HasOwnProp("delay")
        hasSleep := item.HasOwnProp("sleep")

        ; 组合键对象
        if hasKey {
            if hasDelay || hasSleep
                throw ValueError(
                    "combo[" index "]: 组合键对象不能同时包含 delay 或 sleep"
                )

            key := item.key
            mods := hasMods ? item.mods : ""

            ValidateKey(key, index)
            ValidateMods(mods, index)

            return {
                type: "send",
                value: "{Blind}" mods key
            }
        }

        ; delay 对象
        if hasDelay || hasSleep {
            if hasDelay && hasSleep
                throw ValueError(
                    "combo[" index "]: 不能同时包含 delay 和 sleep"
                )

            delayValue := hasDelay ? item.delay : item.sleep

            ValidateDelay(delayValue, index)

            return {
                type: "delay",
                value: delayValue
            }
        }

        throw ValueError(
            "combo[" index "]: 对象必须是 {key: ..., mods: ...}、"
            . "{delay: ...} 或 {sleep: ...}"
        )
    }

    ; 数字表示延迟
    itemType := Type(item)

    if itemType = "Integer" || itemType = "Float" {
        ValidateDelay(item, index)

        return {
            type: "delay",
            value: item
        }
    }

    ; 字符串表示单个按键
    if itemType = "String" {
        ValidateStandaloneKey(item, index)

        return {
            type: "send",
            value: "{Blind}" item
        }
    }

    throw TypeError(
        "combo[" index "]: 只允许单个按键、组合键对象或数字延迟"
    )
}


ValidateKey(key, index)
{
    if Type(key) != "String" || key = ""
        throw ValueError(
            "combo[" index "].key: 必须是单个按键名称，不能是空字符串"
        )

    ; 普通组合键中的 key 只能是一个字符。
    ; 特殊按键可以使用 AHK 名称，例如 Enter、Esc、F1。
    if StrLen(key) = 1
        return

    ; 允许的特殊键名
    allowedNames := Map(
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
        "Numpad0", true,
        "Numpad1", true,
        "Numpad2", true,
        "Numpad3", true,
        "Numpad4", true,
        "Numpad5", true,
        "Numpad6", true,
        "Numpad7", true,
        "Numpad8", true,
        "Numpad9", true,
        "NumpadAdd", true,
        "NumpadSub", true,
        "NumpadMult", true,
        "NumpadDiv", true,
        "NumpadDot", true,
        "NumpadEnter", true
    )

    if RegExMatch(key, "i)^F([1-9]|1[0-9]|2[0-4])$")
        return

    if allowedNames.Has(key)
        return

    throw ValueError(
        "combo[" index "].key: 不允许连续多个按键：" key
    )
}


ValidateStandaloneKey(key, index)
{
    if key = ""
        throw ValueError(
            "combo[" index "]: 按键不能为空"
        )

    ; 普通字符串只能表示一个字符。
    if StrLen(key) = 1
        return

    ; 特殊键必须用 {Enter}、{Esc}、{F1} 这种形式。
    if RegExMatch(key, "^\{[^{}]+\}$")
        return

    throw ValueError(
        "combo[" index "]: " key " 不是单个按键。"
    )
}


ValidateMods(mods, index)
{
    if Type(mods) != "String"
        throw TypeError(
            "combo[" index "].mods: 必须是字符串"
        )

    ; AHK 修饰符：
    ; ^ Ctrl
    ; ! Alt
    ; + Shift
    ; # Win
    if !RegExMatch(mods, "^[\^\!\+\#]*$")
        throw ValueError(
            "combo[" index "].mods: 只能使用 ^、!、+、#"
        )
}


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
                        Send(action.value)
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
