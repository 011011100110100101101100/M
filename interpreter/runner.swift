import Foundation

@main
struct Main {
    static func main() {
        let path = CommandLine.arguments.last!
        let url = URL(fileURLWithPath: path)
        do {
            let m = try String(contentsOf: url, encoding: .utf8)
            let tokens = lex(m)
            let ast = parse(tokens)
            let env = Environment()
            let out = evaluate(ast, env)
            if case let .integer(i) = out {
                print(i)
            } else if case let .vector(v) = out {
                for e in v {
                    if case let .integer(n) = e { print(n, terminator: " ") }
                }
                print("")
            } else if case let .function(args, body, env) = out {
                print(args, body, env)
            }
        } catch {
            print("readError: cannot read \(path)")
        }
    }
}
