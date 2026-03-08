import SwiftUI

struct AppFontModifier: ViewModifier {
    @AppStorage("useSerifFont") private var useSerifFont = false
    let style: Font.TextStyle
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(.system(style, design: useSerifFont ? .serif : .default, weight: weight))
    }
}

extension View {
    func appFont(_ style: Font.TextStyle = .body, weight: Font.Weight? = nil) -> some View {
        modifier(AppFontModifier(style: style, weight: weight))
    }
}
