import SwiftUI

enum Theme {
    static let accent = Color(red: 0.22, green: 0.47, blue: 0.93)
}

/// `State` the property wrapper. Newer SDKs also ship an `@State` macro whose plugin is
/// missing from Command Line Tools-only toolchains; a typealias never resolves to the macro.
typealias ViewState<Value> = State<Value>
