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

; 双击最大间隔，单位：毫秒
DEFAULT_DOUBLE_MS := 200


; ============================================================
; 创建监听器
; ============================================================

gesture := KeyGesture(
    DEFAULT_LONG_MS,
    DEFAULT_DOUBLE_MS
)

; ============================================================
; 通用按键手势类
; ============================================================

class KeyGesture
{
    Prefix := "$"

    __New(defaultLongMs, defaultDoubleMs)
    {
        this.DefaultLongMs   := defaultLongMs
        this.DefaultDoubleMs := defaultDoubleMs

        ; 每个键的状态
        this.States := Map()

        ; 回调函数
        this.OnSingle := 0
        this.OnDouble := 0
        this.OnLong := 0
    }


    ; --------------------------------------------------------
    ; 添加一个按键
    ;
    ; key       ：AHK 按键名称，例如 "a"、"F1"、"LButton"
    ; longMs    ：该键的长按阈值
    ; doubleMs  ：该键的双击间隔
    ; --------------------------------------------------------
    Add(key, longMs := unset, doubleMs := unset)
    {
        if this.States.Has(key)
            return

        state := {
            IsDown: false,
            DownTick: 0,

            ; 当前短按次数
            ClickCount: 0,

            ; 用于让旧的单击计时器失效
            Generation: 0,

            LongMs: IsSet(longMs)
                ? longMs
                : this.DefaultLongMs,

            DoubleMs: IsSet(doubleMs)
                ? doubleMs
                : this.DefaultDoubleMs
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
            ; 长按不参与单击/双击判断
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
        ; 第二次短按松开：判定双击
        ; ----------------------------------------------------
        if state.ClickCount >= 2
        {
            state.ClickCount := 0
            state.Generation++

            if IsObject(this.OnDouble)
                this.OnDouble.Call(key)

            return
        }


        ; ----------------------------------------------------
        ; 第一次短按松开：
        ; 等待双击窗口结束后，再判定为普通单击
        ; ----------------------------------------------------
        callback := ObjBindMethod(
            this,
            "_ConfirmSingle",
            key,
            currentGeneration
        )

        SetTimer callback, -state.DoubleMs
    }


    ; --------------------------------------------------------
    ; 双击等待超时，确认第一次点击是普通单击
    ; --------------------------------------------------------
    _ConfirmSingle(key, generation, *)
    {
        if !this.States.Has(key)
            return

        state := this.States[key]

        ; 如果期间发生了第二次点击，
        ; 这个旧计时器就失效
        if state.Generation != generation
            return

        if state.ClickCount != 1
            return

        state.ClickCount := 0
        state.Generation++

        if IsObject(this.OnSingle)
            this.OnSingle.Call(key)
    }
}



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
            } else if item.HasOwnProp("delay") {
                actions.Push({
                    type: "delay",
                    value: item.delay
                })
            } else if item.HasOwnProp("sleep") {
                actions.Push({
                    type: "delay",
                    value: item.sleep
                })
            }
        } else {
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
    global comboQueue, queueRunning, delayTime, invokeKey

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
    } finally {
        queueRunning := false

        ; 防止处理结束前恰好又加入了任务
        if comboQueue.Length > 0 {
            queueRunning := true
            SetTimer(ProcessComboQueue, -1)
        }
    }
}


; 随机延时
RandomDelay(baseTime)
{
    minTime := Max(0, Round(baseTime * 0.85))
    maxTime := Max(minTime, Round(baseTime * 1.15))

    Sleep(Random(minTime, maxTime))
}
