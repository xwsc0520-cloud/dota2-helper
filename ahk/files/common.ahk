SendMode("Input")
SetNumLockState("AlwaysOn")
SetWorkingDir(A_ScriptDir)

SetTitleMatchMode(2)
DetectHiddenWindows(true)

; ============================================================
; 配置
; ============================================================

; 长按判定时间，单位：毫秒
DEFAULT_LONG_MS := 500

; 连击最大间隔，单位：毫秒
DEFAULT_CLICK_MS := 250


; ============================================================
; 创建监听器
; ============================================================

gesture := KeyGesture(
    DEFAULT_LONG_MS,
    DEFAULT_CLICK_MS
)

; ============================================================
; 通用按键手势类
; 支持：单击、双击、三击、长按
; ============================================================

class KeyGesture
{
    Prefix := "$"

    __New(defaultLongMs, defaultClickMs)
    {
        this.DefaultLongMs  := defaultLongMs
        this.DefaultClickMs := defaultClickMs

        ; 每个键的状态
        this.States := Map()

        ; 回调函数
        this.OnSingle := 0
        this.OnDouble := 0
        this.OnTriple := 0
        this.OnLong := 0
    }


    ; --------------------------------------------------------
    ; 添加一个按键
    ;
    ; key      ：AHK 按键名称，例如 "a"、"F1"、"LButton"
    ; longMs   ：该键的长按阈值
    ; clickMs  ：每次连击之间允许的最大间隔
    ; --------------------------------------------------------
    Add(key, longMs := unset, clickMs := unset)
    {
        if this.States.Has(key)
            return

        state := {
            IsDown: false,
            DownTick: 0,

            ; 当前连续短按次数
            ClickCount: 0,

            ; 用于让旧计时器失效
            Generation: 0,

            LongMs: IsSet(longMs)
                ? longMs
                : this.DefaultLongMs,

            ClickMs: IsSet(clickMs)
                ? clickMs
                : this.DefaultClickMs
        }

        this.States[key] := state

        downHotkey := this.Prefix key
        upHotkey   := this.Prefix key " up"

        Hotkey downHotkey, ObjBindMethod(this, "_OnDown", key)
        Hotkey upHotkey, ObjBindMethod(this, "_OnUp", key)
    }


    ; --------------------------------------------------------
    ; 按键按下
    ; --------------------------------------------------------
    _OnDown(key, *)
    {
        state := this.States[key]

        ; 忽略键盘自动重复
        if state.IsDown
            return

        state.IsDown := true
        state.DownTick := A_TickCount
    }


    ; --------------------------------------------------------
    ; 按键松开
    ; --------------------------------------------------------
    _OnUp(key, *)
    {
        state := this.States[key]

        ; 没有检测到对应的按下，忽略
        if !state.IsDown
            return

        state.IsDown := false

        duration := A_TickCount - state.DownTick

        ; ----------------------------------------------------
        ; 长按
        ; ----------------------------------------------------
        if duration >= state.LongMs
        {
            ; 长按不参与连击判断
            state.ClickCount := 0
            state.Generation++

            if IsObject(this.OnLong)
                this.OnLong.Call(key, duration)

            return
        }


        ; ----------------------------------------------------
        ; 短按
        ; ----------------------------------------------------
        state.ClickCount++
        state.Generation++

        currentGeneration := state.Generation

        ; ----------------------------------------------------
        ; 第三次短按松开：判定三击
        ; ----------------------------------------------------
        if state.ClickCount >= 3
        {
            state.ClickCount := 0
            state.Generation++

            if IsObject(this.OnTriple)
                this.OnTriple.Call(key)

            return
        }


        ; ----------------------------------------------------
        ; 第一次或第二次短按松开：
        ; 等待下一次点击
        ; ----------------------------------------------------
        callback := ObjBindMethod(
            this,
            "_ConfirmClick",
            key,
            currentGeneration
        )

        SetTimer callback, -state.ClickMs
    }


    ; --------------------------------------------------------
    ; 连击等待超时
    ;
    ; 1 次点击：单击
    ; 2 次点击：双击
    ; 3 次点击：三击
    ; --------------------------------------------------------
    _ConfirmClick(key, generation, *)
    {
        if !this.States.Has(key)
            return

        state := this.States[key]

        ; 如果期间发生了新的点击，
        ; 当前旧计时器失效
        if state.Generation != generation
            return

        clickCount := state.ClickCount

        if clickCount <= 0
            return

        ; 清空状态
        state.ClickCount := 0
        state.Generation++

        switch clickCount {
            case 1:
                if IsObject(this.OnSingle)
                    this.OnSingle.Call(key)

            case 2:
                if IsObject(this.OnDouble)
                    this.OnDouble.Call(key)

            case 3:
                if IsObject(this.OnTriple)
                    this.OnTriple.Call(key)
        }
    }
}

; ============================================================
; 组合队列
; ============================================================

comboQueue := []
queueRunning := false

; 默认按键后的随机延时
global delayTime := 50


; 添加一个组合
; combo 可以包含：
;   "a"              按键
;   {key: "a"}       按键
;   {delay: 100}     延时
;   {sleep: 100}     延时，和 delay 等价
AddCombo(combo)
{
    global comboQueue, queueRunning

    ; 复制一份，避免外部继续修改原数组
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
        else {
            ; 普通字符串直接视为按键
            actions.Push({
                type: "key",
                value: item
            })
        }
    }

    comboQueue.Push(actions)

    if !queueRunning {
        queueRunning := true
        SetTimer(ProcessComboQueue, -1)
    }
}


; 按加入顺序处理队列
ProcessComboQueue()
{
    global comboQueue, queueRunning, delayTime

    try {
        while comboQueue.Length > 0 {
            combo := comboQueue.RemoveAt(1)

            for action in combo {
                switch action.type {
                    case "key":
                        key := action.value
                        Send("{Blind}" key)
                        RandomDelay(delayTime)

                    case "delay":
                        ; 手动指定的延时通常不需要再次随机化
                        RandomDelay(action.value)
                }
            }
        }
    }
    finally {
        queueRunning := false

        ; 防止处理结束前恰好又加入了任务
        if comboQueue.Length > 0 {
            queueRunning := true
            SetTimer(ProcessComboQueue, -1)
        }
    }
}


; ============================================================
; 随机延时
; ============================================================

RandomDelay(baseTime)
{
    minTime := Max(0, Round(baseTime * 0.85))
    maxTime := Max(minTime, Round(baseTime * 1.15))

    Sleep(Random(minTime, maxTime))
}
