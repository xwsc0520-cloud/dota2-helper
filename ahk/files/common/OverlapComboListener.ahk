#Requires AutoHotkey v2.0

class OverlapComboListener {
    static IDLE := 0
    static WAITING := 1
    static SINGLE := 2
    static COMBO := 3

    /*
        OnSingleDown(group, key, data)
        OnSingleUp(group, key, data)
        OnComboDown(keyA, dataA, keyB, dataB)
        OnComboUp(keyA, dataA, keyB, dataB)

        delayA / delayB：
            对应组按下后，自动触发单键的等待时间，单位 ms。
    */

    __New(
        onSingleDown,
        onSingleUp,
        onComboDown,
        onComboUp,
        delayA := 128,
        delayB := 128,
        criterion := 0
    ) {
        if !HasMethod(onSingleDown, "Call")
            throw TypeError("onSingleDown 必须是可调用对象。")

        if !HasMethod(onSingleUp, "Call")
            throw TypeError("onSingleUp 必须是可调用对象。")

        if !HasMethod(onComboDown, "Call")
            throw TypeError("onComboDown 必须是可调用对象。")

        if !HasMethod(onComboUp, "Call")
            throw TypeError("onComboUp 必须是可调用对象。")

        if !IsNumber(delayA) || delayA < 0
            throw ValueError("delayA 必须是不小于 0 的数值。")

        if !IsNumber(delayB) || delayB < 0
            throw ValueError("delayB 必须是不小于 0 的数值。")

        this.OnSingleDown := onSingleDown
        this.OnSingleUp := onSingleUp
        this.OnComboDown := onComboDown
        this.OnComboUp := onComboUp

        this.DelayA := delayA
        this.DelayB := delayB
        this.Criterion := criterion
        this.Enabled := false

        this.KeysA := Map()
        this.KeysB := Map()
        this.Hotkeys := Map()
    }


    AddA(key, data := "") {
        this._RequireDisabled()
        this._RequireKeyName(key)

        if this._HasKey(key)
            throw ValueError("按键重复注册：" key)

        this.KeysA[key] := this._CreateKeyState("A", key, data)
        this._AddHotkeys(key)

        return this
    }


    AddB(key, data := "") {
        this._RequireDisabled()
        this._RequireKeyName(key)

        if this._HasKey(key)
            throw ValueError("按键重复注册：" key)

        this.KeysB[key] := this._CreateKeyState("B", key, data)
        this._AddHotkeys(key)

        return this
    }


    Enable() {
        if this.Enabled
            return this

        this._ResetStates(false)
        this.Enabled := true
        this._SelectHotkeyContext()

        try {
            for name, callback in this.Hotkeys
                Hotkey(name, callback, "On")
        } finally {
            HotIf()
        }

        return this
    }


    Disable() {
        if this.Enabled {
            this._SelectHotkeyContext()

            try {
                for name, callback in this.Hotkeys
                    Hotkey(name, "Off")
            } finally {
                HotIf()
            }
        }

        this.Enabled := false
        this._ResetStates(true)

        return this
    }


    Reset() {
        this._ResetStates(true)
        return this
    }


    _CreateKeyState(group, key, data) {
        return {
            group: group,
            key: key,
            data: data,

            phase: OverlapComboListener.IDLE,
            timerToken: 0,

            ; 只有 A 组使用：keyB => 是否为 ACTIVE
            pairs: Map()
        }
    }


    _AddHotkeys(key) {
        this.Hotkeys["$*" key] := ObjBindMethod(
            this, "_HandleKeyDown", key
        )

        this.Hotkeys["$*" key " Up"] := ObjBindMethod(
            this, "_HandleKeyUp", key
        )
    }


    _HandleKeyDown(key, *) {
        if !this._CanRun()
            return

        state := this._GetKeyState(key)

        if !state
            return

        ; 已经处于按下周期：忽略自动重复。
        if state.phase != OverlapComboListener.IDLE
            return

        state.phase := OverlapComboListener.WAITING
        state.timerToken += 1
        token := state.timerToken

        delay := state.group = "A" ? this.DelayA : this.DelayB

        if delay = 0 {
            this._EnterSingle(state)
        }
        else {
            SetTimer(
                ObjBindMethod(
                    this, "_SingleDelayTimer", state, token
                ),
                -delay
            )
        }

        this._CheckCombosFor(state)
    }


    _HandleKeyUp(key, *) {
        state := this._GetKeyState(key)

        if !state
            return

        canRun := this._CanRun()
        oldPhase := state.phase

        ; 失效当前按键周期的计时器。
        state.timerToken += 1

        /*
         * 先退出按下状态，避免业务回调间接触发重复处理。
         */
        state.phase := OverlapComboListener.IDLE

        if canRun {
            switch oldPhase {
                case OverlapComboListener.WAITING:
                    ; 短按：在松开时补发完整单键事件。
                    this.OnSingleDown.Call(
                        state.group, state.key, state.data
                    )
                    this.OnSingleUp.Call(
                        state.group, state.key, state.data
                    )

                case OverlapComboListener.SINGLE:
                    this.OnSingleUp.Call(
                        state.group, state.key, state.data
                    )
            }
        }

        ; COMBO 松开不发单键事件，但需结束涉及它的组合。
        this._EndPairsFor(state, canRun)
    }


    _SingleDelayTimer(state, token) {
        if state.timerToken != token
            return

        if state.phase != OverlapComboListener.WAITING
            return

        if !this._CanRun()
            return

        this._EnterSingle(state)
    }


    _EnterSingle(state) {
        if state.phase != OverlapComboListener.WAITING
            return false

        state.phase := OverlapComboListener.SINGLE
        state.timerToken += 1

        this.OnSingleDown.Call(
            state.group, state.key, state.data
        )

        return true
    }


    _CheckCombosFor(state) {
        if !this._CanJoinCombo(state)
            return

        if state.group = "A" {
            for keyB, stateB in this.KeysB {
                if this._CanJoinCombo(stateB)
                    this._TryStartPair(state, stateB)
            }
        }
        else {
            for keyA, stateA in this.KeysA {
                if this._CanJoinCombo(stateA)
                    this._TryStartPair(stateA, state)
            }
        }
    }


    _CanJoinCombo(state) {
        return state.phase = OverlapComboListener.WAITING
            || state.phase = OverlapComboListener.COMBO
    }


    _TryStartPair(stateA, stateB) {
        if !this._CanJoinCombo(stateA)
            return false

        if !this._CanJoinCombo(stateB)
            return false

        if !GetKeyState(stateA.key, "P")
            return false

        if !GetKeyState(stateB.key, "P")
            return false

        if stateA.pairs.Has(stateB.key) && stateA.pairs[stateB.key]
            return false

        ; INACTIVE -> ACTIVE
        stateA.pairs[stateB.key] := true

        ; WAITING -> COMBO；已为 COMBO 的键保持 COMBO。
        stateA.phase := OverlapComboListener.COMBO
        stateB.phase := OverlapComboListener.COMBO

        ; 两侧的单键计时器均失效。
        stateA.timerToken += 1
        stateB.timerToken += 1

        this.OnComboDown.Call(
            stateA.key,
            stateA.data,
            stateB.key,
            stateB.data
        )

        return true
    }


    _EndPairsFor(state, sendUpEvents) {
        if state.group = "A" {
            for keyB, active in state.pairs {
                if !active
                    continue

                ; ACTIVE -> INACTIVE
                state.pairs[keyB] := false

                if sendUpEvents {
                    stateB := this.KeysB[keyB]

                    this.OnComboUp.Call(
                        state.key,
                        state.data,
                        stateB.key,
                        stateB.data
                    )
                }
            }
        }
        else {
            for keyA, stateA in this.KeysA {
                if !stateA.pairs.Has(state.key)
                    continue

                if !stateA.pairs[state.key]
                    continue

                ; ACTIVE -> INACTIVE
                stateA.pairs[state.key] := false

                if sendUpEvents {
                    this.OnComboUp.Call(
                        stateA.key,
                        stateA.data,
                        state.key,
                        state.data
                    )
                }
            }
        }
    }


    _ResetStates(sendUpEvents) {
        /*
         * 先将组合标记为 INACTIVE，再发 ComboUp。
         * 避免业务回调重复结束同一组合。
         */
        for keyA, stateA in this.KeysA {
            for keyB, active in stateA.pairs {
                if !active
                    continue

                stateA.pairs[keyB] := false

                if sendUpEvents {
                    stateB := this.KeysB[keyB]

                    this.OnComboUp.Call(
                        stateA.key,
                        stateA.data,
                        stateB.key,
                        stateB.data
                    )
                }
            }
        }

        /*
         * 只对 SINGLE 状态补发 SingleUp。
         * WAITING 尚未发送 SingleDown，不补发单键事件。
         */
        for key, state in this.KeysA
            this._ResetKeyState(state, sendUpEvents)

        for key, state in this.KeysB
            this._ResetKeyState(state, sendUpEvents)
    }


    _ResetKeyState(state, sendUpEvents) {
        oldPhase := state.phase

        state.phase := OverlapComboListener.IDLE
        state.timerToken += 1

        if sendUpEvents && oldPhase = OverlapComboListener.SINGLE {
            this.OnSingleUp.Call(
                state.group,
                state.key,
                state.data
            )
        }
    }


    _GetKeyState(key) {
        if this.KeysA.Has(key)
            return this.KeysA[key]

        if this.KeysB.Has(key)
            return this.KeysB[key]

        return 0
    }


    _HasKey(key) {
        return this.KeysA.Has(key) || this.KeysB.Has(key)
    }


    _RequireKeyName(key) {
        if !(key is String) || key = ""
            throw TypeError("按键名称必须是非空字符串。")
    }


    _CanRun() {
        if !this.Enabled
            return false

        if this.Criterion {
            if !this.Criterion.Call() {
                this._ResetStates(true)
                return false
            }
        }

        return true
    }


    _SelectHotkeyContext() {
        if this.Criterion
            HotIf(this.Criterion)
        else
            HotIf()
    }


    _RequireDisabled() {
        if this.Enabled
            throw Error("请先 Disable()，再添加按键。")
    }
}
