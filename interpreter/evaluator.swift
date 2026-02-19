indirect enum Value {
    case integer(Int)
    case vector([Value])
    case function(args: [String], body: Node, env: Environment)
}
final class Environment {
    var values: [String: Value] = [:]
    let parent: Environment?
    init (parent: Environment? = nil) {
        self.parent = parent
    }
    func define(_ name: String, _ value: Value) {
        values[name] = value
    }
    func lookup(_ name: String) -> Value {
        if let v = values[name] {
            return v
        }
        if let p = parent {
            return p.lookup(name)
        }
        fatalError("evaluateError: '\(name)' is not defined")
    }
}
func evaluate(_ node: Node, _ env: Environment) -> Value {
    switch node {
        case .identifier(let name): return env.lookup(name)
        case .integer(let n): return .integer(n)
        case .boolean(let bool): return bool ? .integer(1) : .integer(0)
        case .vector(let elements):
            let values = elements.map { evaluate($0, env)}
            return .vector(values)
        case .access(let target, let index):
            let targetNode = target
            let indexValue = evaluate(index, env)
            guard case .integer(let idx) = indexValue else { fatalError("evaluateError: Index must be a integer") }
            if case .vector(let elements) = targetNode {
                guard idx >= 0 && idx < elements.count else { fatalError("evaluateError: Index out of range") }
                return evaluate(elements[idx], env)
            } else {
                let v = evaluate(target, env)
                guard case .vector(let values) = v else { fatalError("evaluateError: Expected a vector") }
                guard idx >= 0 && idx < values.count else { fatalError("evaluateError: Index out of range") }
                return values[idx]
            }
        case .unary(let op, let expr):
            let value = evaluate(expr, env)
            switch (op, value) {
                case (.minus, .integer(let n)): return .integer(-n)
                default: fatalError("evaluateError: Invalid unary operation")
            }
        case .binary(let op, let left, let right):
            let lv = evaluate(left, env)
            let rv = evaluate(right, env)
            switch (op, lv, rv) {
                case (.plus, .integer(let a), .integer(let b)): return .integer(a + b)
                case (.minus, .integer(let a), .integer(let b)): return .integer(a - b)
                case (.times, .integer(let a), .integer(let b)): return .integer(a * b)
                case (.divide, .integer(let a), .integer(let b)): return .integer(a / b)
                case (.equal, .integer(let a), .integer(let b)): return a == b ? .integer(1) : .integer(0)
                case (.greater, .integer(let a), .integer(let b)): return a > b ? .integer(1) : .integer(0)
                case (.less, .integer(let a), .integer(let b)): return a < b ? .integer(1) : .integer(0)
                case (.and, .integer(let a), .integer(let b)): return a & b != 0 ? .integer(1) : .integer(0)
                case (.or, .integer(let a), .integer(let b)): return a | b != 0 ? .integer(1) : .integer(0)
                default: fatalError("evaluateError: Invalid binary operation")
            }
        case .def(let name, let args, let body):
            let fn = Value.function(args: args, body: body, env: env)
            env.define(name, fn)
            return fn
        case .postfix(let callee, let args):
            let calleeValue = evaluate(callee, env)
            guard case .function(let params, let body, let closureEnv) = calleeValue else { fatalError("evaluateError: Not a function") }
            guard params.count == args.count else { fatalError("evaluateError: Argument count mismatch") }
            let childEnv = Environment(parent: closureEnv)
            for (param, arg) in zip(params, args) {
                let argValue = evaluate(arg, env)
                childEnv.define(param, argValue)
            }
            return evaluate(body, childEnv)
        case .program(let nodes):
            var result: Value = .integer(0)
            for node in nodes {
                result = evaluate(node, env)
            }
            return result
    }
}
