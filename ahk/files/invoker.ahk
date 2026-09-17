#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

; ============================================================
; TEST MODE
; ============================================================

; true  = 在记事本中测试
; false = 只在 Dota 2 中运行
testMode := true

; ============================================================
; INCLUDE
; ============================================================

#Include %A_ScriptDir%\utility.ahk

; ============================================================
; TRAY ICON
; ============================================================

iconPath := A_ScriptDir "\icons\invoker.jpg"

if FileExist(iconPath)
    TraySetIcon(iconPath)

; ============================================================
; CONFIGURATION
; ============================================================

; 施放技能后自动补三个火球
eee_after_casts := true

; 是否处于神杖状态
aghanim := false

; 技能调用键
invokeKey := "r"

; 技能栏
spellSlot1 := "d"
spellSlot2 := "f"

; 三球
quas  := "q"
wex   := "w"
exort := "e"

; 物品
item1 := "1"  ; Urn
item2 := "2"  ; Eul
item3 := "3"  ; Blink

; 选择英雄
selectHero := "F1"

; ============================================================
; TARGET WINDOW
; ============================================================

IsTargetActive()
{
    global testMode

    if testMode
        return WinActive("ahk_exe notepad.exe")

    return WinActive("ahk_exe dota2.exe")
}

; ============================================================
; HOTKEYS
; ============================================================

#HotIf IsTargetActive()

; ------------------------------------------------------------
; TOGGLE
; ------------------------------------------------------------

ScrollLock::
{
    Suspend(-1)
}

; ------------------------------------------------------------
; RESTORE SPACE
; ------------------------------------------------------------

; Space 被用作组合键后，必须补上这个热键，
; 否则单独按 Space 不会产生正常的空格/游戏按键。
Space::SendInput("{Space}")

; ------------------------------------------------------------
; QUICK TRIPLE ORBS
; ------------------------------------------------------------

Space & q::SendInput("qqq")
Space & w::SendInput("www")
Space & e::SendInput("eee")

; ------------------------------------------------------------
; AGHANIM TOGGLE
; ------------------------------------------------------------

; Alt+1：切换神杖状态
Alt & 1::
{
    global aghanim

    aghanim := !aghanim

    if aghanim {
        ToolTip("Aghanim: ON")
        SoundBeep(750, 100)
    } else {
        ToolTip("Aghanim: OFF")
        SoundBeep(400, 100)
    }

    SetTimer(HideToolTip, -1000)
}

; ------------------------------------------------------------
; QUICK BUY AGHANIM
; ------------------------------------------------------------

; 原脚本 Alt+1 重复定义，因此这里改成 Alt+2。
Alt & 2::
{
    SendInput("{Enter}aghanim's scepter{Enter}")
    KeyWait("2")
}

; ============================================================
; COMBO MACROS
; ============================================================

; Meteor + Blast
Space & s::
{
    invokeCombo("eew", "d")
    invokeCombo("qwe", "f")
    postCastActions()
}

; Tornado + Meteor + Blast + Sun Strike
Space & d::
{
    invokeCombo("wwq", "d")
    invokeCombo("eew", "f")
    invokeCombo("qwe", "d")
    invokeCombo("eee", "f")
    postCastActions()
}

; Forge Spirit + Alacrity
Space & z::
{
    invokeCombo("eeq", "d")
    invokeCombo("wwe", "f")
    postCastActions()
}

; EMP + Tornado
Space & x::
{
    invokeCombo("www", "d")
    invokeCombo("wwq", "f")
    postCastActions()
}

; Cold Snap + Forge Spirit
Space & a::
{
    invokeCombo("qqq", "d")
    invokeCombo("eeq", "f")
    postCastActions()
}

; ============================================================
; ESCAPE MECHANICS
; ============================================================

; Blink + Ghost Walk
Space & f::
{
    global item3, selectHero

    useItem(item3)
    invokeCombo("qqw", "d")
    SendInput("{" selectHero "}")
}

; Blink + Ghost Walk + TP Base
Space & g::
{
    global item3, selectHero

    useItem(item3)
    invokeCombo("qqw", "d")

    ; 使用重命名后的函数，避免与 utility.ahk 的 tpBase() 冲突。
    sendTpBaseCommand()

    SendInput("{" selectHero "}")
}

; ============================================================
; INSTANT CAST
; Alt + key
; ============================================================

Alt & a::invokeCombo("qqq", "d") ; Cold Snap
Alt & s::invokeCombo("qqw", "d") ; Ghost Walk
Alt & d::invokeCombo("qqe", "d") ; Ice Wall
Alt & f::invokeCombo("www", "d") ; EMP
Alt & g::invokeCombo("wwq", "d") ; Tornado
Alt & z::invokeCombo("wwe", "d") ; Alacrity
Alt & x::invokeCombo("eee", "d") ; Sun Strike
Alt & c::invokeCombo("eeq", "d") ; Forge Spirit
Alt & v::invokeCombo("eew", "d") ; Chaos Meteor
Alt & b::invokeCombo("qwe", "d") ; Deafening Blast

; ============================================================
; PREPARE CAST
; Middle Mouse Button + key
; ============================================================

MButton & a::SendInput("qqqr") ; Cold Snap
MButton & s::SendInput("qqwr") ; Ghost Walk
MButton & d::SendInput("qqer") ; Ice Wall
MButton & f::SendInput("wwwr") ; EMP
MButton & g::SendInput("wwqr") ; Tornado
MButton & z::SendInput("wwer") ; Alacrity
MButton & x::SendInput("eeer") ; Sun Strike
MButton & c::SendInput("eeqr") ; Forge Spirit
MButton & v::SendInput("eewr") ; Chaos Meteor
MButton & b::SendInput("qwer") ; Deafening Blast

; ============================================================
; TEST HOTKEYS
; ============================================================

; F8：测试发送 tpbase
F8::
{
    sendTpBaseCommand()
}

; F9：显示当前测试模式
F9::
{
    global testMode

    if testMode
        ToolTip("当前模式：记事本测试")
    else
        ToolTip("当前模式：Dota 2")

    SetTimer(HideToolTip, -1500)
}

#HotIf

; ============================================================
; CORE FUNCTIONS
; ============================================================

invokeCombo(orbs, slot)
{
    global invokeKey, eee_after_casts

    ; 输入三球和 Invoke。
    SendInput(orbs invokeKey)
    Sleep(30)

    ; 施放指定技能栏。
    SendInput(slot)

    if eee_after_casts {
        Sleep(50)
        SendInput("eee")
    }
}

postCastActions()
{
    global aghanim, testMode

    ; 记事本测试时不等待 2～6 秒。
    if testMode {
        Sleep(200)
        SoundBeep(500, 100)
        return
    }

    if aghanim
        Sleep(2000)
    else
        Sleep(6000)

    SoundBeep(500, 100)
}

useItem(itemKey)
{
    global testMode

    ; 记事本测试时不发送 Alt，避免激活记事本菜单。
    if testMode {
        SendInput(itemKey)
        Sleep(50)
        return
    }

    SendInput("{Alt down}" itemKey "{Alt up}")
    Sleep(50)
}

; 已从 tpBase() 重命名，避免和 utility.ahk 中的函数冲突。
sendTpBaseCommand()
{
    SendInput("{Enter}tpbase{Enter}")
    Sleep(100)
}

castAll(urn := false)
{
    global item1

    if urn {
        SendInput(item1)
        Sleep(55)
    }

    SendInput("d")
    Sleep(55)

    SendInput("f")
}

HideToolTip()
{
    ToolTip()
}