enum Binary: Equatable {
    case and, or
    case equal, greater, less
    case plus, minus
    case times, divide
}
enum Unary: Equatable {
    case minus
}
indirect enum Node: Equatable {
    case program([Node])
    case def(name: String, args: [String], body: Node)
    case postfix(callee: Node, args: [Node])
    case access(target: Node, index: Node)
    case vector(elements: [Node])
    case binary(op: Binary, left: Node, right: Node)
    case unary(op: Unary, expr: Node)
    case identifier(String)
    case integer(Int)
    case boolean(Bool)
}
var tokens: [Token] = []
var i = 0
func peek() -> Token { tokens[i] }
func next() { i += 1 }
func match(_ t: Token) -> Bool {
    guard i < tokens.count else { return false }
    if peek() == t {
        next()
        return true
    }
    return false
}
func isDef() -> Bool {
    let tmp = i
    guard case .identifier = peek() else { return false }
    next()
    guard match(.leftParen) else {
        i = tmp
        return false
    }
    var parenDepth = 1
    while i < tokens.count && parenDepth > 0 && peek() != .eof {
        if peek() == .leftParen { parenDepth += 1 }
        if peek() == .rightParen { parenDepth -= 1 }
        next()
    }
    if parenDepth == 0 && match(.assign) {
        i = tmp
        return true
    }
    i = tmp
    return false
}
func parse(_ t: [Token]) -> Node {
    tokens = t
    i = 0
    var nodes: [Node] = []
    while peek() != .eof {
        if isDef() { nodes.append(parseDef())} else { nodes.append(parseExpr()) }
    }
    return .program(nodes)
}
func parseDef() -> Node {
    guard case .identifier(let name) = peek() else { fatalError("parseError: expected identifier") }
    next()
    guard match(.leftParen) else { fatalError("parseError: expected '('") }
    var args: [String] = []
    if case .identifier(let first) = peek() {
        args.append(first)
        next()
        while match(.comma) {
            guard case .identifier(let arg) = peek() else { fatalError("parseError: expected identifier") }
            args.append(arg)
            next()
        }
    }
    guard match(.rightParen) else { fatalError("parseError: expected ')'") }
    guard match(.assign) else { fatalError("parseError: expected '='") }
    let body = parseExpr()
    return .def(name: name, args: args, body: body)
}
func parseExpr() -> Node {
    return parseOr()
}
func parseOr() -> Node {
    var node = parseAnd()
    while match(.or) {
        let rhs = parseAnd()
        node = .binary(op: .or, left: node, right: rhs)
    }
    return node
}
func parseAnd() -> Node {
    var node = parseEqual()
    while match(.and) {
        let rhs = parseEqual()
        node = .binary(op: .and, left: node, right: rhs)
    }
    return node
}
func parseEqual() -> Node {
    var node = parseComparison()
    while match(.equal) {
        let rhs = parseComparison()
        node = .binary(op: .equal, left: node, right: rhs)
    }
    return node
}
func parseComparison() -> Node {
    var node = parseAdd()
    while true {
        if match(.greater) {
            let rhs = parseAdd()
            node = .binary(op: .greater, left: node, right: rhs)
        } else if match(.less) {
            let rhs = parseAdd()
            node = .binary(op: .less, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseAdd() -> Node {
    var node = parseMul()
    while true {
        if match(.plus) {
            let rhs = parseMul()
            node = .binary(op: .plus, left: node, right: rhs)
        } else if match(.minus) {
            let rhs = parseMul()
            node = .binary(op: .minus, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseMul() -> Node {
    var node = parseUnary()
    while true {
        if match(.times) {
            let rhs = parseUnary()
            node = .binary(op: .times, left: node, right: rhs)
        } else if match(.divide) {
            let rhs = parseUnary()
            node = .binary(op: .divide, left: node, right: rhs)
        } else { break }
    }
    return node
}
func parseUnary() -> Node {
    if match(.minus) {
        let operand = parseUnary()
        return .unary(op: .minus, expr: operand)
    }
    return parsePostfix()
}
func parsePostfix() -> Node {
    var node = parseAtom()
    while true {
        if match(.leftParen) {
            var args: [Node] = []
            if peek() != .rightParen {
                repeat {
                    args.append(parseExpr())
                } while match(.comma)
            }
            guard match(.rightParen) else { fatalError("parseError: Expected ')'") }
            node = .postfix(callee: node, args: args)
        } else if match(.leftBracket) {
            let index = parseExpr()
            guard match(.rightBracket) else { fatalError("parseError: Expected ']'") }
            node = .access(target: node, index: index)
        } else { break }
    }
    return node
}
func parseAtom() -> Node {
    switch peek() {
        case .identifier(let name):
            next()
            return .identifier(name)
        case .integer(let n):
            next()
            return .integer(n)
        case .boolean(let bool):
            next()
            return .boolean(bool)
        case .leftParen:
            next()
            let expr = parseExpr()
            guard match(.rightParen) else { fatalError("parseError: Expected ')'") }
            return expr
        case .leftBracket:
            return parseVector()
        default:
            fatalError("parseError: Unexpected token \(peek())")
    }
}
func parseVector() -> Node {
    guard match(.leftBracket) else { fatalError("parseError: Expected '['") }
    var elements: [Node] = []
    if peek() != .rightBracket {
        repeat {
            elements.append(parseExpr())
        } while match(.comma)
    }
    guard match(.rightBracket) else { fatalError("parseError: Expected ']'") }
    return .vector(elements: elements)
}
