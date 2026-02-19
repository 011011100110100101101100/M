enum Token: Equatable {
    case identifier(String)
    case integer(Int)
    case boolean(Bool)
    case leftParen, rightParen
    case leftBracket, rightBracket
    case comma
    case assign
    case plus, minus, times, divide
    case equal, greater, less
    case and, or
    case eof
}
func lex(_ m: String) -> [Token] {
    let chars = Array(m)
    var i = 0
    var tokens: [Token] = []
    while i < chars.count {
        guard !chars[i].isWhitespace else {
            i += 1
            continue
        }
        guard chars[i] != "'" else {
            i += 1
            while chars[i] != "'" { i += 1 }
            i += 1
            continue
        }
        guard !chars[i].isLetter && chars[i] != "_" else {
            let start = i
            while i < chars.count && chars[i].isLetter { i += 1 }
            let text = String(chars[start..<i])
            tokens.append(.identifier(text))
            continue
        }
        guard !chars[i].isNumber else {
            let start = i
            while i < chars.count && chars[i].isNumber { i += 1 }
            let text = String(chars[start..<i])
            tokens.append(.integer(Int(text)!))
            continue
        }
        switch chars[i] {
            case "!": tokens.append(.boolean(true))
            case "?": tokens.append(.boolean(false))
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case "[": tokens.append(.leftBracket)
            case "]": tokens.append(.rightBracket)
            case ",": tokens.append(.comma)
            case "=": tokens.append(.assign)
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*": tokens.append(.times)
            case "/": tokens.append(.divide)
            case "^": tokens.append(.equal)
            case ">": tokens.append(.greater)
            case "<": tokens.append(.less)
            case "&": tokens.append(.and)
            case "|": tokens.append(.or)
            default : fatalError("lexError: cannot lex '\(chars[i])'")
        }
        i += 1
    }
    tokens.append(.eof)
    return tokens
}
