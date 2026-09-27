SwitchOnly(skill) {
    SwitchSkill(skill)
}

SwitchThenCast(skill) {
    global DSkill, FSkill

    ; 已在槽位中：直接释放，不发送 R
    if DSkill = skill {
        CastSkill(skill, "d")
        return
    }

    if FSkill = skill {
        CastSkill(skill, "f")
        return
    }

    SwitchSkill(skill)
    CastSkill(skill, "d")
}

SwitchSkill(skill) {
    global DSkill, FSkill
    global SkillByName, RLastCast

    combo := []
    Loop Parse, SkillByName[skill].combo
        combo.Push(A_LoopField)
    combo.Push("r")
    combo.Push(dl)
    AddCombo(combo)

    if skill != FSkill && skill != DSkill {
        RLastCast := A_TickCount
    }

    if skill != DSkill {
        FSkill := DSkill
        DSkill := skill
    }

    return true
}

CastSkill(skill, position) {
    global SkillByName, dl

    combo := []

    for item in SkillByName[skill].cast {
        if item = "df" {
            item := position
        }
        combo.Push(item)
    }

    combo.Push(dl)
    AddCombo(combo)
    MarkSkillCast(skill)
}

CastSlot(position) {
    global dl

    if position = "d" {
        skill := DSkill
    } else if position = "f" {
        skill := FSkill
    }

    if skill = "" {
        AddCombo([position, dl])
        return
    }

    CastSkill(skill, position)
}