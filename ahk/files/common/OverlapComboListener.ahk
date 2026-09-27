#Requires AutoHotkey v2.0


class OverlapComboListener {
    __New(criterion := 0) {
        this.Criterion := criterion
        this.Enabled := false

        this.Keys := Map()
        this.Modifiers := Map()
        this.ModifierOrder := []
        this.Hotkeys := Map()
    }


    AddKey(key, onSingle, data := "") {
        this._RequireDisabled()

        if this.Keys.Has(key) || this.Modifiers.Has(key)
            throw ValueError("按键重复注册：" key)

        this.Keys[key] := {
            data: data,
            onSingle: onSingle,
            down: false,
            pending: false,
            comboTriggered: false,
            sequence: 0
        }

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

        return this
    }


    AddModifier(key, onCombo) {
        this._RequireDisabled()

        if this.Modifiers.Has(key) || this.Keys.Has(key)
            throw ValueError("按键重复注册：" key)

        this.Modifiers[key] := {
            onCombo: onCombo,
            down: false
        }

        this.ModifierOrder.Push(key)

        this.Hotkeys["$*" key] := ObjBindMethod(
            this,
            "_HandleModifierDown",
            key
        )

        this.Hotkeys["$*" key " Up"] := ObjBindMethod(
            this,
            "_HandleModifierUp",
            key
        )

        return this
    }


    Enable() {
        if this.Enabled
            return this

        this.Reset()
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
        this.Reset()

        return this
    }


    Reset() {
        for key, state in this.Keys {
            state.down := false
            state.pending := false
            state.comboTriggered := false
            state.sequence += 1
        }

        for modifier, state in this.Modifiers
            state.down := false
    }


    _HandleKeyDown(key, *) {
        if !this._CanRun()
            return

        state := this.Keys[key]

        ; 防止按住按键时的自动重复
        if state.down && GetKeyState(key, "P")
            return

        state.down := true
        state.pending := true
        state.comboTriggered := false
        state.sequence += 1

        /*
            普通键先按下，修饰键之前已经按住。
            不限制两个键之间的时间，只要修饰键此刻仍按住即可。
        */
        for modifier in this.ModifierOrder {
            modifierState := this.Modifiers[modifier]

            if modifierState.down {
                if this._TriggerCombo(key, modifier)
                    return
            }
        }
    }


    _HandleKeyUp(key, *) {
        if !this.Keys.Has(key)
            return

        state := this.Keys[key]

        ; 先记录松开
        state.down := false

        /*
            只有普通键松开时才处理单键。
            如果之前已经触发组合，则不触发单键。
        */
        if state.pending && !state.comboTriggered {
            state.pending := false

            if this._CanRun()
                state.onSingle.Call(key, state.data)
        }
        else {
            state.pending := false
        }
    }


    _HandleModifierDown(modifier, *) {
        if !this._CanRun()
            return

        state := this.Modifiers[modifier]

        ; 防止自动重复
        if state.down && GetKeyState(modifier, "P")
            return

        state.down := true

        /*
            修饰键后按下：
            只要普通键当前仍处于按下状态，
            就可以形成组合，不限制等待时间。
        */
        for key, keyState in this.Keys {
            if keyState.down && keyState.pending
                this._TriggerCombo(key, modifier)
        }
    }


    _HandleModifierUp(modifier, *) {
        if this.Modifiers.Has(modifier)
            this.Modifiers[modifier].down := false
    }


    _TriggerCombo(key, modifier) {
        keyState := this.Keys[key]

        if !keyState.pending
            return false

        /*
            最终确认：两个按键必须在这一刻同时按下。
        */
        if !GetKeyState(key, "P")
            return false

        if !GetKeyState(modifier, "P")
            return false

        keyState.comboTriggered := true
        keyState.pending := false

        this.Modifiers[modifier].onCombo.Call(
            key,
            keyState.data,
            modifier
        )

        return true
    }


    _CanRun() {
        if !this.Enabled
            return false

        if this.Criterion {
            if !this.Criterion.Call() {
                this.Reset()
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
