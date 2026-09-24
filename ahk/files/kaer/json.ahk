; ============================================================
; JXON JSON Parser for AutoHotkey v2
; ============================================================

Jxon_Load(src, args*) {
    static q := Chr(34)

    if IsObject(src) {
        if src is File {
            src := src.Read()
        } else {
            throw TypeError("Jxon_Load() 的参数必须是 JSON 字符串或文件对象")
        }
    }

    if Type(src) != "String"
        throw TypeError("Jxon_Load() 的参数必须是字符串")

    pos := 1
    result := Jxon_ParseValue(src, &pos)

    Jxon_SkipWhitespace(src, &pos)

    if pos <= StrLen(src)
        throw Error("JSON 末尾存在无效内容，位置：" pos)

    return result
}


Jxon_ParseValue(src, &pos) {
    Jxon_SkipWhitespace(src, &pos)

    if pos > StrLen(src)
        throw Error("JSON 意外结束")

    char := SubStr(src, pos, 1)

    switch char {
        case "{":
            return Jxon_ParseObject(src, &pos)

        case "[":
            return Jxon_ParseArray(src, &pos)

        case Chr(34):
            return Jxon_ParseString(src, &pos)

        case "t":
            Jxon_Expect(src, &pos, "true")
            return true

        case "f":
            Jxon_Expect(src, &pos, "false")
            return false

        case "n":
            Jxon_Expect(src, &pos, "null")
            return ""

        default:
            if RegExMatch(
                SubStr(src, pos),
                "^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?",
                &match
            ) {
                pos += StrLen(match[0])
                return Number(match[0])
            }

            throw Error(
                "无法解析 JSON 值，位置：" pos
                . "，字符：" char
            )
    }
}


Jxon_ParseObject(src, &pos) {
    object := Map()

    ; 跳过 {
    pos++

    Jxon_SkipWhitespace(src, &pos)

    ; 空对象
    if SubStr(src, pos, 1) = "}" {
        pos++
        return object
    }

    while true {
        Jxon_SkipWhitespace(src, &pos)

        if SubStr(src, pos, 1) != Chr(34)
            throw Error("JSON 对象的键必须是字符串，位置：" pos)

        key := Jxon_ParseString(src, &pos)

        Jxon_SkipWhitespace(src, &pos)

        if SubStr(src, pos, 1) != ":" {
            throw Error("JSON 对象缺少冒号，位置：" pos)
        }

        pos++

        value := Jxon_ParseValue(src, &pos)
        object[key] := value

        Jxon_SkipWhitespace(src, &pos)

        char := SubStr(src, pos, 1)

        if char = "}" {
            pos++
            return object
        }

        if char != "," {
            throw Error(
                "JSON 对象缺少逗号或右大括号，位置：" pos
            )
        }

        pos++
    }
}


Jxon_ParseArray(src, &pos) {
    array := []

    ; 跳过 [
    pos++

    Jxon_SkipWhitespace(src, &pos)

    ; 空数组
    if SubStr(src, pos, 1) = "]" {
        pos++
        return array
    }

    while true {
        array.Push(Jxon_ParseValue(src, &pos))

        Jxon_SkipWhitespace(src, &pos)

        char := SubStr(src, pos, 1)

        if char = "]" {
            pos++
            return array
        }

        if char != "," {
            throw Error(
                "JSON 数组缺少逗号或右中括号，位置：" pos
            )
        }

        pos++
    }
}


Jxon_ParseString(src, &pos) {
    length := StrLen(src)
    result := ""

    ; 跳过开始的双引号
    pos++

    while pos <= length {
        char := SubStr(src, pos, 1)

        ; 字符串结束
        if char = Chr(34) {
            pos++
            return result
        }

        ; 普通字符
        if char != "\" {
            result .= char
            pos++
            continue
        }

        ; 转义字符
        pos++

        if pos > length
            throw Error("JSON 字符串转义不完整")

        escape := SubStr(src, pos, 1)

        switch escape {
            case Chr(34):
                result .= Chr(34)

            case "\":
                result .= "\"

            case "/":
                result .= "/"

            case "b":
                result .= Chr(8)

            case "f":
                result .= Chr(12)

            case "n":
                result .= "`n"

            case "r":
                result .= "`r"

            case "t":
                result .= "`t"

            case "u":
                if pos + 4 > length
                    throw Error("JSON Unicode 转义不完整")

                hex := SubStr(src, pos + 1, 4)

                if !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
                    throw Error(
                        "无效的 Unicode 转义：" hex
                    )

                result .= Chr("0x" hex)
                pos += 4

            default:
                throw Error(
                    "未知的 JSON 转义字符：" escape
                )
        }

        pos++
    }

    throw Error("JSON 字符串缺少结束双引号")
}


Jxon_SkipWhitespace(src, &pos) {
    length := StrLen(src)

    while pos <= length {
        char := SubStr(src, pos, 1)

        if char = " "
            || char = "`t"
            || char = "`r"
            || char = "`n" {
            pos++
        } else {
            break
        }
    }
}


Jxon_Expect(src, &pos, expected) {
    actual := SubStr(src, pos, StrLen(expected))

    if actual != expected {
        throw Error(
            "JSON 内容错误，期待：" expected
            . "，实际：" actual
            . "，位置：" pos
        )
    }

    pos += StrLen(expected)
}
