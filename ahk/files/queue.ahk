global delay := 30
global comboQueue := []
global queueRunning := false
global queueCancel := false

;~Esc::CancelComboQueue()

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

    actions := []

    for item in combo {
        if IsObject(item) {
            ; 组合键对象：
            ; {key: "v", mods: "!"}
            if item.HasOwnProp("key") {
                key := item.key
                mods := item.HasOwnProp("mods") ? item.mods : ""

                actions.Push({
                    type: "send",
                    value: "{Blind}" mods key
                })
            }
            ; 延迟对象：
            ; {delay: 100}
            else if item.HasOwnProp("delay") {
                actions.Push({
                    type: "delay",
                    value: item.delay
                })
            }
            ; 兼容 sleep 对象
            else if item.HasOwnProp("sleep") {
                actions.Push({
                    type: "delay",
                    value: item.sleep
                })
            }
        }
        else if Type(item) = "Integer" {
            ; 数字直接表示延迟
            actions.Push({
                type: "delay",
                value: item
            })
        }
        else {
            ; 普通单键
            actions.Push({
                type: "send",
                value: "{Blind}" item
            })
        }
    }

    comboQueue.Push(actions)

    if !queueRunning {
        queueCancel := false
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
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
                        RandomDelay(delay)

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

    while true {
        if queueCancel
            return

        elapsed := A_TickCount - startTime
        remaining := targetTime - elapsed

        if remaining <= 0
            break

        Sleep(Min(5, remaining))
    }
}