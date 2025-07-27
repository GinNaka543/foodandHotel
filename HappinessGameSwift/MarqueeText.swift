import SwiftUI

// MARK: - MarqueeText View
struct MarqueeText: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Text(text)
                .font(.system(size: 12))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear.preference(
                            key: WidthPreferenceKey.self,
                            value: textGeometry.size.width
                        )
                    }
                )
                .onPreferenceChange(WidthPreferenceKey.self) { width in
                    textWidth = width
                }
                .offset(x: offset)
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: offset)
                .onAppear {
                    if textWidth > geometry.size.width {
                        offset = geometry.size.width
                        withAnimation {
                            offset = -textWidth
                        }
                    }
                }
        }
        .clipped()
    }
}

// MARK: - Preference Key for Width
struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}