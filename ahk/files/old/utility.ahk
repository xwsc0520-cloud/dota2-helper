#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetNumLockState("AlwaysOn")
SetCapsLockState("Off")
SetWorkingDir(A_ScriptDir)

SetTitleMatchMode(2)
DetectHiddenWindows(true)

; ============================================================
; VARIABLES
; ============================================================

timerPaused := false
workStatus := true
runStatus := false

displayX := 1366
displayY := 768

; 物品栏坐标，在 imageLoad() 中初始化
slot1x := 0
slot1y := 0
slot2x := 0
slot2y := 0
slot3x := 0
slot3y := 0
slot4x := 0
slot4y := 0
slot5x := 0
slot5y := 0
slot6x := 0
slot6y := 0
slot7x := 0
slot7y := 0
slot8x := 0
slot8y := 0
slot9x := 0
slot9y := 0

; ============================================================
; ICON
; ============================================================

I_Icon   := A_ScriptDir "\icons\dota2.png"
I_Default := A_ScriptDir "\icons\dota2.png"

if FileExist(I_Icon)
    TraySetIcon(I_Icon)
else if FileExist(I_Default)
    TraySetIcon(I_Default)

; ============================================================
; CONFIG
; ============================================================

directional_move := "h"
move_to         := "m"
attack          := "a"
stop            := "s"

selectHero := "1"
selectAll  := "2"
lastActions := "l"

; Item
item1 := "WheelUp"
item2 := "WheelDown"
item3 := "g"
item4 := "c"
item5 := "v"
item6 := "t"

; Camera
camera_9  := "Numpad7"
camera_10 := "Numpad8"

; Teleport
tp := "3"

; Ability
ability1 := "q"
ability2 := "w"
ability3 := "e"
ability4 := "d"
ability5 := "f"
ability6 := "r"

; Courier
pickCourier    := "4"
deliveItem     := "x"
openShop       := "b"
courierAbility1 := "q"
courierAbility2 := "w"
courierAbility3 := "e"
courierAbility4 := "d"
courierAbility5 := "f"
courierAbility6 := "r"

; ============================================================
; FUNCTIONS
; ============================================================

CloseScript(name)
{
    DetectHiddenWindows(true)
    SetTitleMatchMode("RegEx")

    scriptTitle := "i)" name ".* ahk_class AutoHotkey"

    if WinExist(scriptTitle) {
        WinClose(scriptTitle)

        try {
            WinWaitClose(scriptTitle, , 2)
            result := "Closed " name
        } catch {
            result := "Unable to close " name
        }
    } else {
        result := name " not found"
    }

    SetTitleMatchMode(2)
    return result
}

imageLoad()
{
    global slot1x, slot1y
    global slot2x, slot2y
    global slot3x, slot3y
    global slot4x, slot4y
    global slot5x, slot5y
    global slot6x, slot6y
    global slot7x, slot7y
    global slot8x, slot8y
    global slot9x, slot9y

    iX1 := 700
    iY1 := 700
    iX2 := 1200
    iY2 := 800

    imageToSearch := A_ScriptDir "\bmp\backpack.bmp"

    if !FileExist(imageToSearch) {
        ToolTip("找不到图片：`n" imageToSearch)
        SoundBeep(300, 200)
        SetTimer(() => ToolTip(), -2000)
        return false
    }

    try {
        found := ImageSearch(
            &findX,
            &findY,
            iX1,
            iY1,
            iX2,
            iY2,
            imageToSearch
        )
    } catch as err {
        ToolTip("ImageSearch 出错：`n" err.Message)
        SoundBeep(300, 200)
        SetTimer(() => ToolTip(), -2000)
        return false
    }

    if !found {
        ToolTip("没有找到 backpack.bmp")
        SoundBeep(300, 200)
        SetTimer(() => ToolTip(), -2000)
        return false
    }

    slot4x := findX + 26
    slot4y := findY - 16

    slot1x := slot4x
    slot1y := slot4y - 35

    slot2x := slot1x + 45
    slot2y := slot1y

    slot3x := slot2x + 45
    slot3y := slot2y

    slot5x := slot4x + 45
    slot5y := slot4y

    slot6x := slot5x + 45
    slot6y := slot5y

    ; Backpack
    slot7x := slot4x
    slot7y := findY + 14

    slot8x := slot7x + 45
    slot8y := slot7y

    slot9x := slot8x + 45
    slot9y := slot7y

    ToolTip("物品栏坐标加载成功")
    SetTimer(() => ToolTip(), -1000)

    return true
}

delay()
{
    Sleep(50)
}

delayT(delayTime)
{
    Sleep(delayTime)
}

direct()
{
    global directional_move

    Send(
        "{" directional_move " Down}"
        "{Click Right}"
        "{" directional_move " Up}"
    )
}

backWingBroke()
{
    global move_to, stop

    Send(move_to)
    Sleep(10)
    MouseClick("Left")
    Send(stop)
}

directedAbility(i)
{
    direct()
    Sleep(50)
    ability(i)
}

directedItem(i)
{
    direct()
    Sleep(50)
    item(i)
}

item(i)
{
    global item1, item2, item3, item4, item5, item6

    delay()

    switch i {
        case 1:
            Send("{" item1 "}")
        case 2:
            Send("{" item2 "}")
        case 3:
            Send("{" item3 "}")
        case 4:
            Send("{" item4 "}")
        case 5:
            Send("{" item5 "}")
        case 6:
            Send("{" item6 "}")
    }
}

altItem(i)
{
    global item1, item2, item3, item4, item5, item6

    delay()
    Send("{Alt Down}")
    delay()

    switch i {
        case 1:
            Send("{" item1 "}")
        case 2:
            Send("{" item2 "}")
        case 3:
            Send("{" item3 "}")
        case 4:
            Send("{" item4 "}")
        case 5:
            Send("{" item5 "}")
        case 6:
            Send("{" item6 "}")
    }

    delay()
    Send("{Alt Up}")
}

ability(i)
{
    global ability1, ability2, ability3
    global ability4, ability5, ability6

    delay()

    switch i {
        case 1:
            Send("{" ability1 "}")
        case 2:
            Send("{" ability2 "}")
        case 3:
            Send("{" ability3 "}")
        case 4:
            Send("{" ability4 "}")
        case 5:
            Send("{" ability5 "}")
        case 6:
            Send("{" ability6 "}")
    }
}

altAbility(i)
{
    global ability1, ability2, ability3
    global ability4, ability5, ability6

    Send("{Alt Down}")
    delay()

    switch i {
        case 1:
            Send("{" ability1 "}")
        case 2:
            Send("{" ability2 "}")
        case 3:
            Send("{" ability3 "}")
        case 4:
            Send("{" ability4 "}")
        case 5:
            Send("{" ability5 "}")
        case 6:
            Send("{" ability6 "}")
    }

    delay()
    Send("{Alt Up}")
}

tpBase()
{
    global tp

    Send("{Alt Down}")
    delay()
    Send("{" tp "}")
    delay()
    Send("{Alt Up}")
}

repeater(key, host)
{
    loop {
        Send("{" key "}")
        Sleep(10)

        if !GetKeyState(host, "P")
            break
    }
}

drag(x1, y1, x2, y2)
{
    SendEvent(
        "{Click " x1 " " y1 " Down}"
        "{Click " x2 " " y2 " Up}"
    )
}

dragr(x2, y2, x1, y1)
{
    ; Reversed
    SendEvent(
        "{Click " x1 " " y1 " Down}"
        "{Click " x2 " " y2 " Up}"
    )
}

displayText(textToDisplay)
{
    ToolTip(textToDisplay)
}

clearDisplayText()
{
    ToolTip()
}

loadHeroScript(scriptName, loadText)
{
    global runStatus

    if !runStatus
        return

    scriptPath := A_ScriptDir "\" scriptName

    if !FileExist(scriptPath) {
        displayText("找不到脚本：`n" scriptPath)
        SoundBeep(300, 250)
        SetTimer(clearDisplayText, -2000)
        runStatus := false
        return
    }

    runStatus := false
    displayText(loadText)

    Sleep(2000)
    SoundBeep(200, 200)

    Run(scriptPath)
    ExitApp()
}

toggleTimer()
{
    global timerPaused

    DetectHiddenWindows(true)

    try {
        ; 65306 = Pause/Suspend menu command
        PostMessage(
            0x111,
            65306,
            0,
            0,
            "timer.ahk ahk_class AutoHotkey"
        )
    } catch {
        ToolTip("没有找到 timer.ahk")
        SetTimer(clearDisplayText, -1500)
        return
    }

    if timerPaused {
        SoundBeep(700, 120)
        Sleep(100)
        SoundBeep(700, 180)
        timerPaused := false
    } else {
        SoundBeep(700, 120)
        Sleep(200)
        SoundBeep(500, 120)
        Sleep(200)
        SoundBeep(400, 120)
        timerPaused := true
    }
}

toggleWorkStatus()
{
    global workStatus

    Suspend(-1)

    if workStatus {
        SoundBeep(444, 100)
        Sleep(80)
        SoundBeep(555, 90)
        Sleep(80)
        SoundBeep(333, 80)
        Sleep(80)

        workStatus := false
    } else {
        SoundBeep(640, 120)
        Sleep(55)
        SoundBeep(400, 80)

        workStatus := true
    }
}

; ============================================================
; DOTA 2 HOTKEYS
; ============================================================

#HotIf WinActive("Dota 2")

F7::
{
    imageLoad()

    timerScript := A_ScriptDir "\timer.ahk"

    if FileExist(timerScript)
        Run(timerScript)
    else {
        ToolTip("找不到 timer.ahk")
        SetTimer(clearDisplayText, -1500)
    }
}

Space & F7::
{
    result := CloseScript("timer.ahk")
    ToolTip(result)
    SetTimer(clearDisplayText, -1500)
}

F6::imageLoad()

PgUp::toggleTimer()

; ============================================================
; TELEPORT
; ============================================================

Space & 3::tpBase()

; ============================================================
; DROP ITEMS / PICK ITEMS
; ============================================================

Alt & MButton::
{
    global selectHero, displayX, displayY
    global slot1x, slot1y
    global slot2x, slot2y
    global slot3x, slot3y
    global slot4x, slot4y
    global slot5x, slot5y
    global slot6x, slot6y

    if slot1x = 0 {
        if !imageLoad()
            return
    }

    Send(selectHero)
    delay()
    Send(selectHero)

    drag(slot1x, slot1y, displayX / 2 - 20, displayY / 2 - 30)
    drag(slot2x, slot2y, displayX / 2 - 20, displayY / 2 - 20)
    drag(slot3x, slot3y, displayX / 2 - 20, displayY / 2 - 15)

    drag(slot4x, slot4y, displayX / 2 + 20, displayY / 2 - 30)
    drag(slot5x, slot5y, displayX / 2 + 20, displayY / 2 - 20)
    drag(slot6x, slot6y, displayX / 2 + 20, displayY / 2 - 15)

    Sleep(3000)

    Send(selectHero)
    delay()
    Send(selectHero)
    delay()

    MouseMove(displayX / 2 - 20, displayY / 2 - 30)
    Send("{RButton}")

    MouseMove(displayX / 2 - 20, displayY / 2 - 20)
    Send("{RButton}")

    MouseMove(displayX / 2 - 20, displayY / 2 - 15)
    Send("{RButton}")

    MouseMove(displayX / 2 + 20, displayY / 2 - 30)
    Send("{RButton}")

    MouseMove(displayX / 2 + 20, displayY / 2 - 20)
    Send("{RButton}")

    MouseMove(displayX / 2 + 20, displayY / 2 - 15)
    Send("{RButton}")
}

Space & MButton::
{
    global selectHero
    global slot1x, slot1y
    global slot2x, slot2y
    global slot3x, slot3y
    global slot4x, slot4y
    global slot5x, slot5y
    global slot6x, slot6y
    global slot7x, slot7y
    global slot8x, slot8y
    global slot9x, slot9y

    if slot1x = 0 {
        if !imageLoad()
            return
    }

    Send(selectHero)
    delay()
    Send(selectHero)
    delay()

    drag(slot1x, slot1y, slot7x, slot7y)
    delay()

    drag(slot2x, slot2y, slot8x, slot8y)
    delay()

    drag(slot3x, slot3y, slot9x, slot9y)
    delay()

    dragr(slot1x, slot1y, slot7x, slot7y)
    delay()

    dragr(slot2x, slot2y, slot8x, slot8y)
    delay()

    dragr(slot3x, slot3y, slot9x, slot9y)
    delay()

    drag(slot4x, slot4y, slot7x, slot7y)
    delay()

    drag(slot5x, slot5y, slot8x, slot8y)
    delay()

    drag(slot6x, slot6y, slot9x, slot9y)
    delay()

    dragr(slot4x, slot4y, slot7x, slot7y)
    delay()

    dragr(slot5x, slot5y, slot8x, slot8y)
    delay()

    dragr(slot6x, slot6y, slot9x, slot9y)
    delay()
}

; ============================================================
; EXPRESS GEM DELIVERY
; Only use when courier is at base and you have 1200 gold.
; ============================================================

Numpad7::
{
    global openShop
    global deliveItem
    global pickCourier
    global courierAbility3
    global selectHero

    ; Buy six iron branches
    Sleep(25)
    SendPlay(openShop)

    loop 6 {
        Sleep(25)
        SendPlay("w1")
    }

    Sleep(25)
    SendPlay(deliveItem)

    ; Gem
    SendPlay("r-")

    SendPlay(openShop)
    Sleep(3000)

    SendPlay(deliveItem)
    Sleep(30)

    SendPlay(pickCourier)
    Sleep(25)

    SendPlay(courierAbility3)
    Sleep(25)

    SendPlay(selectHero)
}

; ============================================================
; RIGHT-CLICK SPAMMER
; ============================================================

$LWin::
{
    repeater("RButton", "LWin")
}

; ============================================================
; SCRIPT SWITCHER
; ============================================================

Space & Numpad0::
{
    global runStatus
    runStatus := !runStatus

    ToolTip(runStatus ? "英雄脚本切换：开启" : "英雄脚本切换：关闭")
    SetTimer(clearDisplayText, -1000)
}

:*:kun::
{
    loadHeroScript(
        "kunka.ahk",
        "Kunka will be loaded after beep"
    )
}

:*:sf::
{
    loadHeroScript(
        "sf.ahk",
        "Shadow Fiend will be loaded after beep"
    )
}

:*:sky::
{
    loadHeroScript(
        "sky.ahk",
        "Sky will be loaded after beep"
    )
}

:*:magn::
{
    loadHeroScript(
        "magnus.ahk",
        "Magnus will be loaded after beep"
    )
}

:*:lega::
{
    loadHeroScript(
        "legion.ahk",
        "Legion will be loaded after beep"
    )
}

:*:mars::
{
    loadHeroScript(
        "mars.ahk",
        "Mars will be loaded after beep"
    )
}

:*:wr::
{
    loadHeroScript(
        "windranger.ahk",
        "Windranger will be loaded after beep"
    )
}

:*:es::
{
    ; 保留原文件名 earthsoirit.ahk
    ; 如果实际文件名是 earthspirit.ahk，请自行修改。
    loadHeroScript(
        "earthsoirit.ahk",
        "Earth Spirit will be loaded after beep"
    )
}

:*:cm::
{
    loadHeroScript(
        "cm.ahk",
        "Crystal Maiden will be loaded after beep"
    )
}

:*:axe::
{
    loadHeroScript(
        "axe.ahk",
        "Axe will be loaded after beep"
    )
}

:*:io::
{
    loadHeroScript(
        "io.ahk",
        "Io will be loaded after beep"
    )
}

:*:sand::
{
    loadHeroScript(
        "sand.ahk",
        "Sand King will be loaded after beep"
    )
}

:*:ta::
{
    loadHeroScript(
        "templar.ahk",
        "Templar Assassin will be loaded after beep"
    )
}

:*:inv::
{
    loadHeroScript(
        "invoker.ahk",
        "Shitty Wizard will be loaded after beep"
    )
}

:*:br::
{
    loadHeroScript(
        "bristleback.ahk",
        "Bristleback will be loaded after beep"
    )
}

; ============================================================
; PAUSE / RELOAD
; ============================================================

Numpad0::toggleWorkStatus()

LAlt & Numpad0::Reload()

#HotIf