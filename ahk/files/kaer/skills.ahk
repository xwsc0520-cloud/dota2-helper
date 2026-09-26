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

    ; 不在槽位中：切入 D 后释放
    if SwitchSkill(skill)
        CastSkill(skill, "d")
}

SwitchSkill(skill) {
    global DSkill, FSkill
    global SkillByName, RLastCast

    if !IsRReady() {
        SoundSkillUnavailableAsync()
        return false
    }

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

CastCurrentSlot(position) {
    global DSkill, FSkill

    if position = "d"
        skill := DSkill
    else if position = "f"
        skill := FSkill
    else {
        SoundSkillUnavailableAsync()
        return
    }

    AddCombo([position, dl])
    MarkSkillCast(skill)
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

SoundSkillUnavailableAsync()
{
    SetTimer(() => SoundSkillUnavailable(), -1)
}

SoundSkillUnavailable()
{
    SoundBeep(220, 100)
    Sleep(35)
    SoundBeep(180, 120)
}



