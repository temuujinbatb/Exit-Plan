import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Accent
    static let epAccent     = Color(r: 0.428, g: 0.722, b: 0.494)
    static let epAccentDeep = Color(r: 0.290, g: 0.604, b: 0.369)
    static let epAccentSoft = Color(r: 0.875, g: 0.941, b: 0.890)

    // Light surfaces
    static let epBg         = Color(hex: "ECEEF1")
    static let epBgDeep     = Color(hex: "E4E7EB")
    static let epInk        = Color(hex: "2A2F36")
    static let epInkSoft    = Color(hex: "6B7280")
    static let epInkFaint   = Color(hex: "A0A7B1")

    // Dark surfaces
    static let epBgDk       = Color(hex: "1C1F24")
    static let epBgDeepDk   = Color(hex: "16181C")
    static let epInkDk      = Color(hex: "E8EBF0")
    static let epInkSoftDk  = Color(hex: "8C929B")
    static let epInkFaintDk = Color(hex: "5A5F67")

    // Shadow helpers
    static let neuShadowDark  = Color(r: 0.639, g: 0.694, b: 0.776).opacity(0.45)
    static let neuShadowLight = Color.white.opacity(0.95)
    static let neuShadowDarkDk  = Color.black.opacity(0.45)
    static let neuShadowLightDk = Color(r: 0.204, g: 0.227, b: 0.259).opacity(0.35)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(r: Double, g: Double, b: Double) {
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Environment Helpers

struct EPTheme {
    let isDark: Bool
    var bg:         Color { isDark ? .epBgDk       : .epBg }
    var bgDeep:     Color { isDark ? .epBgDeepDk   : .epBgDeep }
    var ink:        Color { isDark ? .epInkDk       : .epInk }
    var inkSoft:    Color { isDark ? .epInkSoftDk   : .epInkSoft }
    var inkFaint:   Color { isDark ? .epInkFaintDk  : .epInkFaint }
    var shadowDark: Color { isDark ? .neuShadowDarkDk  : .neuShadowDark }
    var shadowLight:Color { isDark ? .neuShadowLightDk : .neuShadowLight }
}

// MARK: - Screen Background

struct EPScreen<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [scheme == .dark ? Color(hex: "22262C") : Color(hex: "F1F3F6"), t.bg, t.bgDeep],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            content
        }
    }
}

// MARK: - Raised Neumorphic Card

struct EPCard<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    var radius: CGFloat = 22
    var padding: CGFloat = 20
    var inset: Bool = false
    let content: Content

    init(radius: CGFloat = 22, padding: CGFloat = 20, inset: Bool = false, @ViewBuilder content: () -> Content) {
        self.radius  = radius
        self.padding = padding
        self.inset   = inset
        self.content = content()
    }

    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(inset ? t.bgDeep : t.bg)
                    .shadow(color: inset ? .clear : t.shadowDark,  radius: inset ? 0 : 10, x: inset ? 0 :  8, y: inset ? 0 :  8)
                    .shadow(color: inset ? .clear : t.shadowLight, radius: inset ? 0 : 10, x: inset ? 0 : -8, y: inset ? 0 : -8)
            )
    }
}

// MARK: - Section Label

struct EPLabel: View {
    @Environment(\.colorScheme) var scheme
    let text: String
    var trailing: String? = nil
    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(t.inkFaint)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Color.epAccentDeep)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Circular Button

struct EPCircleButton<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    var size: CGFloat = 42
    var accent: Bool = false
    var action: (() -> Void)? = nil
    let content: Content

    init(size: CGFloat = 42, accent: Bool = false, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.size    = size
        self.accent  = accent
        self.action  = action
        self.content = content()
    }

    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        Button(action: { action?() }) {
            content
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(accent
                            ? AnyShapeStyle(LinearGradient(colors: [.epAccent, .epAccentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(t.bg))
                        .shadow(color: t.shadowDark,  radius: 6, x:  5, y:  5)
                        .shadow(color: t.shadowLight, radius: 6, x: -5, y: -5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Segmented Control

struct EPSegmented: View {
    @Environment(\.colorScheme) var scheme
    @Binding var selection: String
    let options: [(value: String, label: String, icon: String)]

    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let active = selection == opt.value
                Button {
                    withAnimation(.spring(response: 0.3)) { selection = opt.value }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 13, weight: active ? .medium : .regular))
                        Text(opt.label)
                            .font(.system(size: 13, weight: active ? .medium : .regular))
                            .tracking(0.3)
                    }
                    .foregroundStyle(active ? Color.epAccentDeep : t.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if active {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(t.bg)
                                    .shadow(color: t.shadowDark,  radius: 5, x:  4, y:  4)
                                    .shadow(color: t.shadowLight, radius: 5, x: -4, y: -4)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(t.bgDeep)
                .shadow(color: t.shadowDark,  radius: 5, x:  4, y:  4)
                .shadow(color: t.shadowLight, radius: 5, x: -4, y: -4)
        )
    }
}

// MARK: - Neumorphic Slider

struct EPSlider: View {
    @Environment(\.colorScheme) var scheme
    @Binding var value: Double
    var range: ClosedRange<Double> = 3...30
    var step: Double = 1

    var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var pct: Double { (value - range.lowerBound) / (range.upperBound - range.lowerBound) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 8)
                    .fill(t.bgDeep)
                    .shadow(color: t.shadowDark,  radius: 3, x:  2, y:  2)
                    .shadow(color: t.shadowLight, radius: 3, x: -2, y: -2)
                    .frame(height: 8)

                // Fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.epAccent, .epAccentDeep], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * pct), height: 8)

                // Knob
                Circle()
                    .fill(t.bg)
                    .frame(width: 24, height: 24)
                    .shadow(color: t.shadowDark,  radius: 4, x:  3, y:  3)
                    .shadow(color: t.shadowLight, radius: 4, x: -3, y: -3)
                    .overlay(Circle().strokeBorder(Color.epAccent, lineWidth: 2))
                    .offset(x: max(0, geo.size.width * pct - 12))
                    .gesture(DragGesture().onChanged { drag in
                        let raw = drag.location.x / geo.size.width
                        let clamped = min(1, max(0, raw))
                        let newVal = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        value = (newVal / step).rounded() * step
                    })
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Contact Avatar

struct EPAvatar: View {
    let name: String
    var size: CGFloat = 40

    var initial: String { String(name.prefix(1)).uppercased() }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.epAccentSoft, .epAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text(initial)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
