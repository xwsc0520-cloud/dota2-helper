PgUp::ShowCDGui()
PgDn::HideCDGui()

Up::ChangeHeroLevel(1)
Down::ChangeHeroLevel(-1)

~Esc::ResetAllState()

$d::CastCurrentSlot("d")
$f::CastCurrentSlot("f")

$LAlt::Return

RegisterAllSkillHotkeys() {
    global SkillConfigs

    for config in SkillConfigs
        RegisterOneSkillHotkey(config)
}

RegisterOneSkillHotkey(config) {
    skill := config.name
    hk := config.hotkey

    ; 保持原代码的实际绑定：
    ; Space + 技能键：切换并释放
    ; LAlt + 技能键：只切换
    Hotkey("Space & " hk, (*) => SwitchThenCast(skill))
    Hotkey("LAlt & " hk, (*) => SwitchOnly(skill))
}
