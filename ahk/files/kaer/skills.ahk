SwitchOnly(skill) {
    if skill != ""
        SwitchSkill(skill)
}

SwitchThenCast(skill) {
    global DSkill, FSkill

    if skill = ""
        return

    ; 已在槽位中：直接释放，不发送 R
    if DSkill = skill {
        CastSkill(skill, "d")
        return
    }

    if FSkill = skill {
        CastSkill(skill, "f")
        return
    }

    ; 不在槽位中：切入 D 后释放
    if SwitchSkill(skill)
        CastSkill(skill, "d")
}

SwitchSkill(skill) {
    global DSkill, FSkill

    if skill = ""
        return false

    if DSkill = skill
        return true

    if !IsRReady()
        return false

    ; F 槽技能切到 D：交换槽位
    if FSkill = skill {
        if !SendSwitchCommand(skill, true)
            return false

        oldD := DSkill
        DSkill := skill
        FSkill := oldD
        return true
    }

    ; 保留原有的槽位整理逻辑
    if DSkill != "" && FSkill != "" {
        if !IsSkillReady(DSkill) && IsSkillReady(FSkill)
            SwitchFToD()
    }

    if !SendSwitchCommand(skill, false)
        return false

    FSkill := DSkill
    DSkill := skill
    return true
}

SwitchFToD() {
    global DSkill, FSkill

    if FSkill = "" || !IsRReady()
        return

    skill := FSkill
    oldD := DSkill

    if !SendSwitchCommand(skill, true)
        return

    DSkill := skill
    FSkill := oldD
}

SendSwitchCommand(skill, f_to_d) {
    global SkillByName, RLastCast

    if skill = "" || !SkillByName.Has(skill) || !IsRReady()
        return false

    combo := []

    Loop Parse, SkillByName[skill].combo
        combo.Push(A_LoopField)

    combo.Push("r")
    AddCombo(combo)

    if !f_to_d
        RLastCast := A_TickCount

    return true
}

CastCurrentSlot(position) {
    global DSkill, FSkill

    if position = "d"
        skill := DSkill
    else if position = "f"
        skill := FSkill
    else
        return

    if skill = "" || !IsSkillReady(skill)
        return

    AddCombo([position])
    MarkSkillCast(skill)
}

CastSkill(skill, position) {
    global SkillByName, dl

    if skill = "" || !SkillByName.Has(skill) || !IsSkillReady(skill)
        return

    combo := [dl]

    for item in SkillByName[skill].cast {
        if Type(item) = "String" && item = "df" {
            combo.Push(position)
        } else if IsAltDObject(item) {
            combo.Push({key: position, mods: "!"})
        } else {
            combo.Push(item)
        }
    }

    AddCombo(combo)
    MarkSkillCast(skill)
}

IsAltDObject(item) {
    if !IsObject(item)
        return false

    try {
        return item.key = "df" && item.mods = "!"
    } catch {
        return false
    }
}
