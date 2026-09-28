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
    AddCombo([dl])
    CastSkill(skill, "d")
}

SwitchSkill(skill) {
    global DSkill, FSkill
    global SkillByName, RLastCast

    combo := []
    Loop Parse, SkillByName[skill].combo
        combo.Push(A_LoopField)
    combo.Push("r")
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

CastSkill(skill, key) {
    combo := []
    for item in SkillByName[skill].cast {
        if item = "df" {
            item := key
        }
        combo.Push(item)
    }
    AddCombo(combo)
    MarkSkillCast(skill)
}

CastSlotUp(key) {
    skill := ""
    if key = "d" {
        skill := DSkill
    } else if key = "f" {
        skill := FSkill
    }
    if skill = "" {
        return false
    }

    key := "{" key " up}"
    CastSkill(skill, key)
    return true
}