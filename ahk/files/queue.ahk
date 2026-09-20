global delay_down := 20
global delay := 30

global comboQueue := []
global queueRunning := false
global queueCancel := false

~s::CancelComboQueue()
~RButton::CancelComboQueue()

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
            if item.HasOwnProp("key") {
                actions.Push({
                    type: "key",
                    value: item.key
                })
            }
            else if item.HasOwnProp("delay") {
                actions.Push({
                    type: "delay",
                    value: item.delay
                })
            }
            else if item.HasOwnProp("sleep") {
                actions.Push({
                    type: "delay",
                    value: item.sleep
                })
            }
        }
        else if Type(item) = "Integer" {
            actions.Push({
                type: "delay",
                value: item
            })
        }
        else {
            actions.Push({
                type: "key",
                value: item
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
    global delay_down, delay

    try {
        while comboQueue.Length > 0 && !queueCancel {
            combo := comboQueue.RemoveAt(1)

            for action in combo {
                ; Esc 后立即停止当前组合
                if queueCancel
                    break

                switch action.type {
                    case "key":
                        key := action.value

                        Send("{Blind}{" key " down}")
                        RandomDelay(delay_down)

                        if queueCancel {
                            ; 如果中途取消，确保按键被释放
                            Send("{Blind}{" key " up}")
                            break
                        }

                        Send("{Blind}{" key " up}")
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
            ; 清空剩余队列
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

        ; 分段等待，提高 Esc 响应速度
        Sleep(Min(5, remaining))
    }
}


