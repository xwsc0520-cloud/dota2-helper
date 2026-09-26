; ============================================================
; Dota 2 GSI
; ============================================================

global GSIPid := 0
global GSIPort := 3000

global GSIDataReady := false
global GSILastUpdate := 0

global GSIClockTime := 0
global GSIHeroLevel := 1
global GSIHeroName := ""

global GSIClockFile := A_Temp "\kaer_gsi_clock.txt"
global GSILevelFile := A_Temp "\kaer_gsi_level.txt"
global GSIHeroFile := A_Temp "\kaer_gsi_hero.txt"


StartGSI() {
    global GSIPid, GSIPort
    global GSIClockFile, GSILevelFile, GSIHeroFile

    try FileDelete(GSIClockFile)
    try FileDelete(GSILevelFile)
    try FileDelete(GSIHeroFile)

    psScript := A_Temp "\kaer_gsi_receiver.ps1"
    psCode := BuildGSIPowerShell(
        GSIPort,
        GSIClockFile,
        GSILevelFile,
        GSIHeroFile
    )

    try FileDelete(psScript)
    FileAppend(psCode, psScript, "UTF-8")

    command := Format(
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{1}"',
        psScript
    )

    Run(command, , "Hide", &GSIPid)

    SetTimer(PollGSIData, 200)
    OnExit(StopGSI)
}


StopGSI(*) {
    global GSIPid

    if GSIPid {
        try ProcessClose(GSIPid)
        GSIPid := 0
    }
}


PollGSIData() {
    global GSIClockFile, GSILevelFile, GSIHeroFile
    global GSIClockTime, GSIHeroLevel, GSIHeroName
    global GSIDataReady, GSILastUpdate
    global HeroLevel, MinHeroLevel, MaxHeroLevel
    global RLevelCDList
    global Linglongxin

    updated := false

    ; 读取游戏时间
    if FileExist(GSIClockFile) {
        try {
            value := Trim(FileRead(GSIClockFile, "UTF-8"))

            if IsNumber(value) {
                GSIClockTime := Number(value)
                updated := true
            }

            FileDelete(GSIClockFile)
        }
    }

    ; 读取英雄等级
    if FileExist(GSILevelFile) {
        try {
            value := Trim(FileRead(GSILevelFile, "UTF-8"))

            if RegExMatch(value, "^\d+$") {
                level := Integer(value)

                if level >= MinHeroLevel
                    && level <= MaxHeroLevel
                    && level <= RLevelCDList.Length {
                    GSIHeroLevel := level
                    HeroLevel := level
                    updated := true

                    if level < 6 {
                        Linglongxin := false
                    }
                }
            }

            FileDelete(GSILevelFile)
        }
    }

    ; 读取英雄名称
    if FileExist(GSIHeroFile) {
        try {
            GSIHeroName := Trim(
                FileRead(GSIHeroFile, "UTF-8")
            )

            FileDelete(GSIHeroFile)
            updated := true
        }
    }

    if updated {
        GSIDataReady := true
        GSILastUpdate := A_TickCount
    }
}


BuildGSIPowerShell(
    port,
    clockFile,
    levelFile,
    heroFile
) {
    clockPath := StrReplace(clockFile, "'", "''")
    levelPath := StrReplace(levelFile, "'", "''")
    heroPath := StrReplace(heroFile, "'", "''")

    return (
        "$ErrorActionPreference = 'SilentlyContinue'`n"
        . "$listener = [System.Net.HttpListener]::new()`n"
        . "$listener.Prefixes.Add('http://127.0.0.1:"
        . port
        . "/')`n"
        . "$listener.Start()`n"
        . "while ($listener.IsListening) {`n"
        . "  $context = $null`n"
        . "  try {`n"
        . "    $context = $listener.GetContext()`n"
        . "    $request = $context.Request`n"
        . "    $body = ''`n"
        . "    if ($request.HttpMethod -eq 'POST') {`n"
        . "      $reader = New-Object "
        . "System.IO.StreamReader($request.InputStream, "
        . "$request.ContentEncoding)`n"
        . "      $body = $reader.ReadToEnd()`n"
        . "      $reader.Close()`n"
        . "      $data = $body | ConvertFrom-Json`n"
        . "      $clock = $data.map.clock_time`n"
        . "      $level = $data.hero.level`n"
        . "      $hero = $data.hero.name`n"
        . "      if ($null -ne $clock) {`n"
        . "        [IO.File]::WriteAllText('"
        . clockPath
        . "', [string]$clock)`n"
        . "      }`n"
        . "      if ($null -ne $level) {`n"
        . "        [IO.File]::WriteAllText('"
        . levelPath
        . "', [string]$level)`n"
        . "      }`n"
        . "      if ($null -ne $hero) {`n"
        . "        [IO.File]::WriteAllText('"
        . heroPath
        . "', [string]$hero)`n"
        . "      }`n"
        . "    }`n"
        . "    $context.Response.StatusCode = 200`n"
        . "    $context.Response.Close()`n"
        . "  } catch {`n"
        . "    try { $context.Response.StatusCode = 500 } catch { }`n"
        . "    try { $context.Response.Close() } catch { }`n"
        . "  }`n"
        . "}`n"
    )
}
