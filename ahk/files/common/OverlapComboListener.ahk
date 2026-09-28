#Requires AutoHotkey v2.0


class OverlapComboListener {
    /*
        全局单键按下回调：

            OnSingleDown(group, key, data)

        全局单键松开回调：

            OnSingleUp(group, key, data)

        全局双键按下回调：

            OnComboDown(keyA, dataA, keyB, dataB)

        全局双键松开回调：

            OnComboUp(keyA, dataA, keyB, dataB)
    */

    __New(
        onSingleDown,
        onSingleUp,
        onComboDown,
        onComboUp,
        delay := 128,
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

        if delay < 0
            throw ValueError("delay 不能小于 0。")

        this.OnSingleDown := onSingleDown
        this.OnSingleUp := onSingleUp
        this.OnComboDown := onComboDown
        this.OnComboUp := onComboUp

        this.Delay := delay
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

        this.KeysA[key] := this._CreateKeyState(
            "A",
            key,
            data
        )

        this._AddHotkeys(key)

        return this
    }


    AddB(key, data := "") {
        this._RequireDisabled()
        this._RequireKeyName(key)

        if this._HasKey(key)
            throw ValueError("按键重复注册：" key)

        this.KeysB[key] := this._CreateKeyState(
            "B",
            key,
            data
        )

        this._AddHotkeys(key)

        return this
    }


    Enable() {
        if this.Enabled
            return this

        this._ClearStates(false)
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
        this._ClearStates(true)

        return this
    }


    Reset() {
        this._ClearStates(true)
    }


    _CreateKeyState(group, key, data) {
        return {
            group: group,
            key: key,
            data: data,

            down: false,

            ; 本次按住期间是否参与过双键
            usedInCombo: false,

            ; 是否已经触发单键按下
            singleDownSent: false,

            ; 是否已经触发单键松开
            singleUpSent: false,

            ; 是否仍允许等待单键超时
            waitingSingle: false,

            ; 当前计时器序号
            timerToken: 0,

            ; A 组键使用，B 组键不使用
            pairs: Map()
        }
    }


    _AddHotkeys(key) {
        this.Hotkeys["$*" key] := ObjBindMethod(
            this,
            "_HandleKeyDown",
            key
        )

        this.Hotkeys["$*" key " Up"] := ObjBindMethod(
            this,
            "_HandleKeyUp",
            key
        )
    }


    _HandleKeyDown(key, *) {
        if !this._CanRun()
            return

        state := this._GetKeyState(key)

        if !state
            return

        /*
         * 忽略自动重复。
         */
        if state.down && GetKeyState(key, "P")
            return

        /*
         * 新的按键周期。
         */
        state.down := true
        state.usedInCombo := false
        state.singleDownSent := false
        state.singleUpSent := false
        state.waitingSingle := true

        state.timerToken += 1
        token := state.timerToken

        /*
         * Delay = 0 时，立即触发单键按下。
         */
        if this.Delay = 0 {
            this._TriggerSingleDown(state)
        }
        else {
            SetTimer(
                ObjBindMethod(
                    this,
                    "_SingleDelayTimer",
                    state,
                    token
                ),
                -this.Delay
            )
        }

        /*
         * 即使这个键在自己的等待计时器启动后，
         * 也要立即检查当前是否已有另一组按键按下。
         */
        this._CheckCombosFor(state)
    }


    _HandleKeyUp(key, *) {
        state := this._GetKeyState(key)

        if !state
            return

        /*
         * 如果当前不在有效监听状态，
         * 仍然清理内部状态，但不发送业务回调。
         */
        canRun := this._CanRun()

        state.down := false
        state.waitingSingle := false
        state.timerToken += 1

        /*
         * 尚未触发单键按下，且也没有参与双键：
         *
         *     A 按下
         *     A 松开
         *
         * 立即补发：
         *
         *     单键按下
         *     单键松开
         */
        if canRun
            && !state.usedInCombo
            && !state.singleDownSent {
            this._TriggerSingleDown(state)
        }

        /*
         * 如果单键按下事件已经发送，
         * 现在发送单键松开。
         */
        if canRun
            && state.singleDownSent
            && !state.singleUpSent {
            this._TriggerSingleUp(state)
        }

        /*
         * 当前键松开后，所有涉及它的组合对都结束。
         * 这些组合对下次重新同时按下时可以再次触发。
         */
        this._ClearPairsFor(state)

        /*
         * 清理本次按键周期。
         */
        state.usedInCombo := false
        state.singleDownSent := false
        state.singleUpSent := false
    }


    _SingleDelayTimer(state, token) {
        /*
         * 计时器属于旧按键周期时直接失效。
         */
        if state.timerToken != token
            return

        if !this.Enabled
            return

        if !state.down
            return

        if !state.waitingSingle
            return

        if state.usedInCombo
            return

        if !this._CanRun()
            return

        /*
         * 超时后触发单键按下。
         * 此后不再参与任何双键。
         */
        this._TriggerSingleDown(state)
    }


    _TriggerSingleDown(state) {
        if state.singleDownSent
            return false

        if state.usedInCombo
            return false

        state.singleDownSent := true
        state.waitingSingle := false

        this.OnSingleDown.Call(
            state.group,
            state.key,
            state.data
        )

        return true
    }


    _TriggerSingleUp(state) {
        if !state.singleDownSent
            return false

        if state.singleUpSent
            return false

        state.singleUpSent := true

        this.OnSingleUp.Call(
            state.group,
            state.key,
            state.data
        )

        return true
    }


    _CheckCombosFor(state) {
        /*
         * 已经触发单键按下后，
         * 该键不再参与任何双键。
         */
        if state.singleDownSent
            return

        if !state.waitingSingle
            return

        if state.group = "A" {
            for keyB, stateB in this.KeysB {
                if !stateB.down
                    continue

                this._TryTriggerCombo(state, stateB)
            }
        }
        else {
            for keyA, stateA in this.KeysA {
                if !stateA.down
                    continue

                this._TryTriggerCombo(stateA, state)
            }
        }
    }


    _TryTriggerCombo(stateA, stateB) {
        /*
         * 任意一方已经触发单键按下，
         * 则不能再形成双键。
         */
        if stateA.singleDownSent
            return false

        if stateB.singleDownSent
            return false

        if !stateA.waitingSingle
            return false

        if !stateB.waitingSingle
            return false

        if !stateA.down || !stateB.down
            return false

        if !GetKeyState(stateA.key, "P")
            return false

        if !GetKeyState(stateB.key, "P")
            return false

        if !stateA.pairs.Has(stateB.key) {
            stateA.pairs[stateB.key] := {
                triggered: false,
                downSent: false,
                upSent: false
            }
        }

        pair := stateA.pairs[stateB.key]

        /*
         * 同一对按键在仍然同时按住期间只触发一次。
         */
        if pair.triggered
            return false

        pair.triggered := true
        pair.downSent := true
        pair.upSent := false

        stateA.usedInCombo := true
        stateB.usedInCombo := true

        stateA.waitingSingle := false
        stateB.waitingSingle := false

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


    _ClearPairsFor(state) {
        if state.group = "A" {
            for keyB, pair in state.pairs {
                if pair.triggered && pair.downSent && !pair.upSent {
                    stateB := this.KeysB[keyB]

                    pair.upSent := true

                    this.OnComboUp.Call(
                        state.key,
                        state.data,
                        stateB.key,
                        stateB.data
                    )
                }

                pair.triggered := false
                pair.downSent := false
                pair.upSent := false
            }
        }
        else {
            for keyA, stateA in this.KeysA {
                if !stateA.pairs.Has(state.key)
                    continue

                pair := stateA.pairs[state.key]

                if pair.triggered && pair.downSent && !pair.upSent {
                    pair.upSent := true

                    this.OnComboUp.Call(
                        stateA.key,
                        stateA.data,
                        state.key,
                        state.data
                    )
                }

                pair.triggered := false
                pair.downSent := false
                pair.upSent := false
            }
        }
    }


    _ClearStates(sendUpEvents) {
        /*
         * 先处理所有仍处于按下状态的双键。
         */
        if sendUpEvents {
            for keyA, stateA in this.KeysA {
                for keyB, pair in stateA.pairs {
                    if !pair.triggered
                        continue

                    if !pair.downSent || pair.upSent
                        continue

                    stateB := this.KeysB[keyB]

                    pair.upSent := true

                    this.OnComboUp.Call(
                        stateA.key,
                        stateA.data,
                        stateB.key,
                        stateB.data
                    )
                }
            }

            /*
             * 再处理已经发送单键按下、但还没有发送单键松开的键。
             */
            for key, state in this.KeysA {
                if state.singleDownSent && !state.singleUpSent {
                    state.singleUpSent := true

                    this.OnSingleUp.Call(
                        state.group,
                        state.key,
                        state.data
                    )
                }
            }

            for key, state in this.KeysB {
                if state.singleDownSent && !state.singleUpSent {
                    state.singleUpSent := true

                    this.OnSingleUp.Call(
                        state.group,
                        state.key,
                        state.data
                    )
                }
            }
        }

        /*
         * 使所有已经存在的计时器失效。
         */
        for key, state in this.KeysA {
            state.timerToken += 1
            state.down := false
            state.usedInCombo := false
            state.singleDownSent := false
            state.singleUpSent := false
            state.waitingSingle := false

            for keyB, pair in state.pairs {
                pair.triggered := false
                pair.downSent := false
                pair.upSent := false
            }
        }

        for key, state in this.KeysB {
            state.timerToken += 1
            state.down := false
            state.usedInCombo := false
            state.singleDownSent := false
            state.singleUpSent := false
            state.waitingSingle := false
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
                this._ClearStates(true)
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
