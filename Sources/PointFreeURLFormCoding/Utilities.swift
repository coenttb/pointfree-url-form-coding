import Foundation

// MARK: - Identity Function
package func id<A>(_ a: A) -> A {
    return a
}

// MARK: - Function Composition
precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardPipe
}

infix operator >>>: ForwardComposition

package func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
    return { a in g(f(a)) }
}

// MARK: - Pipe Forward
precedencegroup ForwardPipe {
    associativity: left
}

infix operator |>: ForwardPipe

package func |> <A, B>(a: A, f: (A) -> B) -> B {
    return f(a)
}
