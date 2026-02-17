import Foundation

enum Token: Equatable {
    case identifier(String)
    case number(Int)
    case string(String)
    case lParen, rParen
    case comma
    case assign
    case equal, greater, less
    case plus, minus, times, divide
    case eof
}
func lexer(_ input: String) -> [Token] {
    let chars = Array(input)
    var i = 0
    var tokens: [Token] = []
    while i < chars.count {
        guard !chars[i].isWhitespace else {
            i += 1
            continue
        }
        guard !chars[i].isLetter && chars[i] != "_" else {
            let start = i
            while chars[i].isLetter { i += 1 }
            let text = String(chars[start..<i])
            tokens.append(.identifier(text))
            continue
        }
        guard !chars[i].isNumber else {
            let start = i
            while chars[i].isNumber { i += 1 }
            let text = String(chars[start..<i])
            tokens.append(.number(Int(text)!))
            continue
        }
        guard chars[i] != "'" else {
            i += 1
            let start = i
            while chars[i] != "'" { i += 1 }
            let text = String(chars[start..<i])
            tokens.append(.string(text))
            i += 1
            continue
        }
        switch chars[i] {
            case "(": tokens.append(.lParen)
            case ")": tokens.append(.rParen)
            case ",": tokens.append(.comma)
            case "=": tokens.append(.assign)
            case "^": tokens.append(.equal)
            case ">": tokens.append(.greater)
            case "<": tokens.append(.less)
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*": tokens.append(.times)
            case "/": tokens.append(.divide)
            default : fatalError("Unhandled character: \(chars[i])")
        }
        i += 1
    }
    tokens.append(.eof)
    return tokens
}
enum BinaryOperator: Equatable {
    case equal, greater, less
    case plus, minus
    case times, divide
}
enum UnaryOperator: Equatable {
    case minus
}
indirect enum Node: Equatable {
    case program([Node])
    case identifier(String)
    case number(Int)
    case string(String)
    case binaryOperation(op: BinaryOperator, left: Node, right: Node)
    case unaryOperation(op: UnaryOperator, expr: Node)
    case assign(name: String, value: Node)
    case call(callee: Node, arguments: [Node])
    case def(name: String, parameters: [String], body: Node)
}
var tokens: [Token] = []
var current = 0
func peek() -> Token? { tokens[current] }
@discardableResult
func advance() -> Token {
    defer { current += 1 }
    return tokens[current]
}
func match(_ expected: Token) -> Bool {
    guard current < tokens.count else { return false }
    if peek() == expected {
        _ = advance()
        return true
    }
    return false
}
func parser(_ t: [Token]) -> Node {
    tokens = t
    current = 0
    var stmts: [Node] = []
    while current < tokens.count {
        if case .eof = tokens[current] { break }
        stmts.append(parseStatement())
    }
    return .program(stmts)
}
func parseStatement() -> Node {
    let left = parseExpr()
    guard current < tokens.count else { return left }
    guard case .assign = tokens[current] else { return left }
    current += 1
    let right = parseStatement()
    if case .identifier(let name) = left {
        return .assign(name: name, value: right)
    }
    if case .call(let callee, let arguments) = left, case .identifier(let fname) = callee {
        var params: [String] = []
        params.reserveCapacity(arguments.count)
        for a in arguments {
            guard case .identifier(let string) = a else {
                fatalError("Invalid parameter type")
            }
            params.append(string)
        }
        return .def(name: fname, parameters: params, body: right)
    }
    fatalError("Invalid assignment target")
}
func parseExpr() -> Node {
    var node = parseTerm()
    while current < tokens.count {
        if match(.plus) {
            let rhs = parseTerm()
            node = .binaryOperation(op: .plus, left: node, right: rhs)
        } else if match(.minus) {
            let rhs = parseTerm()
            node = .binaryOperation(op: .minus, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseComparison() -> Node {
    var node = parseExpr()
    while current < tokens.count {
        if match(.equal) {
            let rhs = parseExpr()
            node = .binaryOperation(op: .equal, left: node, right: rhs)
        } else if match(.greater) {
            let rhs = parseExpr()
            node = .binaryOperation(op: .greater, left: node, right: rhs)
        } else if match(.less) {
            let rhs = parseExpr()
            node = .binaryOperation(op: .less, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseTerm() -> Node {
    var node = parseUnary()
    while current < tokens.count {
        if match(.times) {
            let rhs = parseUnary()
            node = .binaryOperation(op: .times, left: node, right: rhs)
        } else if match(.divide) {
            let rhs = parseUnary()
            node = .binaryOperation(op: .divide, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseUnary() -> Node {
    if match(.minus) {
        let expr = parseUnary()
        return .unaryOperation(op: .minus, expr: expr)
    }
    return parseCall()
}
func parseCall() -> Node {
    var node = parsePrimary()
    while current < tokens.count {
        if match(.lParen) {
            var args: [Node] = []
            if !match(.rParen) {
                repeat {
                    args.append(parseStatement())
                } while match(.comma)
                guard match(.rParen) else { fatalError("Expected ')' after arguments") }
            }
            node = .call(callee: node, arguments: args)
        } else { break }
    }
    return node
}
func parsePrimary() -> Node {
    guard current < tokens.count else { fatalError("Unexpected end of input")}
    let tok = advance()
    switch tok {
        case .identifier(let name): return .identifier(name)
        case .number(let value): return .number(value)
        case .string(let value): return .string(value)
        case .lParen:
            let expr = parseStatement()
            guard match(.rParen) else { fatalError("Expected ')' after expression") }
            return expr
        default: fatalError("Unhandled token: \(tok)")
    }
}
func genState(_ node: Node) -> String {
    switch node {
        case .program(let nodes): return nodes.map(genState).joined(separator: "\n")
        case .def(let name, let params, let body):
            let paramStr = params.map { "int \($0)" }.joined(separator: ", ")
            let bodyStr = genExpr(body)
            return """
            int \(name)(\(paramStr)) {
                return \(bodyStr);
            }
            """
        case .assign(let name, let node): return "\(name) = \(genExpr(node));"
        default: return genExpr(node) + ";"
    }
}
func genExpr(_ node: Node) -> String {
    switch node {
        case .number(let value): return String(value)
        case .string(let value): return "\"\(value)\""
        case .identifier(let name): return name
        case .unaryOperation(let op, let expr): switch op {
            case .minus: return "(-\(genExpr(expr)))"
        }
        case .binaryOperation(let op, let left, let right):
            let l = genExpr(left)
            let r = genExpr(right)
            let opStr: String
            switch op {
                case .plus: opStr = "+"
                case .minus: opStr = "-"
                case .times: opStr = "*"
                case .divide: opStr = "/"
                case .equal: opStr = "=="
                case .greater: opStr = ">"
                case .less: opStr = "<"
            }
            return "(\(l) \(opStr) \(r))"
        case .call(let callee, let args):
            let fn = genExpr(callee)
            let argStr = args.map { genExpr($0) }.joined(separator: ", ")
            return "\(fn)(\(argStr))"
        case .assign(let name, let value): return "\(name) = \(genExpr(value));"
        case .def: fatalError("Shouldn't generate code for function definitions")
        case .program: fatalError("Shouldn't generate code for a program node")
    }
}
func runCommand(_ launchPath: String, _ args: [String], _ cwd: URL? = nil) throws {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: launchPath)
    proc.arguments = args
    if let cwd = cwd {
        proc.currentDirectoryURL = cwd
    }
    proc.standardInput = FileHandle.standardInput
    proc.standardOutput = FileHandle.standardOutput
    proc.standardError = FileHandle.standardError
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        throw NSError(domain: "runCommand", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command failed: \(launchPath) \(args)"])
    }
}
let runtime = """
    \n#include <stdio.h>
    int main(void) {
        printf("%d\\n", mout());
        return 0;
    }
    """
func compiler() throws {
    let path = CommandLine.arguments.last!
    let url = URL(fileURLWithPath: path)
    do {
        let m = try String(contentsOf: url, encoding: .utf8)
        let tokens = lexer(m)
        let ast = parser(tokens)
        var c = genState(ast)
        c += runtime
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("m_lang_build_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let cPath = tmp.appendingPathComponent("main.c")
        let exePath = tmp.appendingPathComponent("main")
        try c.write(to: cPath, atomically: true, encoding: .utf8)
        let clang = "/usr/bin/clang"
        try runCommand(clang, ["-o2", cPath.path, "-o", exePath.path], tmp)
        try runCommand(exePath.path, [], tmp)
        try FileManager.default.removeItem(at: tmp)
    } catch {
        fatalError("\(error)")
    }
}
do {
    try compiler()
} catch {
    fatalError("\(error)")
}
