; 技能索引与运行状态
global Skills := []
global SkillByHotkey := Map()
global SkillByName := Map()
global SkillCD := Map()
global SkillLastCast := Map()

global DSkill := ""
global FSkill := ""
global RLastCast := 0

InitSkillState() {
    global SkillConfigs, Skills, SkillByHotkey
    global SkillByName, SkillCD, SkillLastCast

    for config in SkillConfigs {
        skill := config.name

        Skills.Push(skill)
        SkillByHotkey[config.hotkey] := skill
        SkillByName[skill] := config
        SkillCD[skill] := config.cd
        SkillLastCast[skill] := 0
    }
}

MarkSkillCast(skill) {
    global SkillLastCast
    SkillLastCast[skill] := A_TickCount
}

IsSkillReady(skill) {
    global SkillCD, SkillLastCast

    if skill = ""
        return false

    if !SkillCD.Has(skill) || !SkillLastCast.Has(skill)
        return true

    return A_TickCount - SkillLastCast[skill] >= SkillCD[skill]
}

GetSkillRemaining(skill) {
    global SkillCD, SkillLastCast

    if skill = "" || !SkillCD.Has(skill) || !SkillLastCast.Has(skill)
        return 0

    remaining := SkillCD[skill] - (A_TickCount - SkillLastCast[skill])
    return Max(remaining, 0)
}

ChangeHeroLevel(amount) {
    global HeroLevel, MinHeroLevel, MaxHeroLevel, RLevelCDList

    HeroLevel := Max(
        MinHeroLevel,
        Min(HeroLevel + amount, MaxHeroLevel)
    )

    ; 防止等级超过 CD 配置长度
    if HeroLevel > RLevelCDList.Length
        HeroLevel := RLevelCDList.Length
}

GetCurrentRCD() {
    global HeroLevel, RLevelCDList

    if RLevelCDList.Length = 0
        return 0

    level := Max(1, Min(HeroLevel, RLevelCDList.Length))
    return RLevelCDList[level]
}

IsRReady() {
    global RLastCast

    if RLastCast = 0
        return true

    return A_TickCount - RLastCast >= GetCurrentRCD()
}

GetRRemaining() {
    global RLastCast

    if RLastCast = 0
        return 0

    remaining := GetCurrentRCD() - (A_TickCount - RLastCast)
    return Max(remaining, 0)
}

ResetAllState() {
    global DSkill, FSkill, RLastCast, SkillLastCast, Skills

    DSkill := ""
    FSkill := ""
    RLastCast := 0

    for skill in Skills
        SkillLastCast[skill] := 0
}
