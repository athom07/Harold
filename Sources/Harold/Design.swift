import AppKit
import SwiftUI

enum Palette {
    static let background = rgb(0xEDF2F2)
    static let sidebar = rgb(0xF3F7F6)
    static let panel = rgb(0xFFFFFF)
    static let raised = rgb(0xE2EBEB)
    static let border = rgb(0xD7E1E0)
    static let text = rgb(0x102723)
    static let secondary = rgb(0x405652)
    static let muted = rgb(0x526B65)
    static let accent = rgb(0x074A53)
    static let teal = rgb(0x08756E)
    static let mint = rgb(0xC5DFDB)
    static let mist = rgb(0xCFDFE0)
    static let lavender = rgb(0xF0EBFA)
    static let amber = rgb(0x934118)
    static let peach = rgb(0xFBEDE1)

    static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}

extension Font {
    enum HaroldWeight: String {
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "DemiBold"
        case bold = "Bold"
        case heavy = "Heavy"
    }

    static func harold(size: CGFloat, weight: HaroldWeight = .regular) -> Font {
        .custom("AvenirNext-" + weight.rawValue, size: size)
    }
}

struct Surface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var fill = Palette.panel
    var border = Palette.border
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            if reduceTransparency {
                shape.fill(fill)
            } else if #available(macOS 26.0, *) {
                shape.fill(fill.opacity(0.18))
                    .glassEffect(.clear, in: shape)
            } else {
                shape.fill(.thinMaterial)
                    .overlay { shape.fill(fill.opacity(0.22)) }
            }
        }
        .overlay {
            shape.strokeBorder(border, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

struct HoverButtonStyle: ButtonStyle {
    var fill: Color = .clear
    var hover = Palette.teal.opacity(0.09)
    var border: Color = .clear
    var radius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(configuration: configuration, style: self)
    }

    private struct HoverButtonBody: View {
        let configuration: Configuration
        let style: HoverButtonStyle
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: style.radius)
                        .fill(style.fill)
                        .overlay {
                            RoundedRectangle(cornerRadius: style.radius)
                                .fill(style.hover.opacity(hovering || configuration.isPressed ? 1 : 0))
                        }
                }
                .overlay { RoundedRectangle(cornerRadius: style.radius).strokeBorder(style.border).allowsHitTesting(false) }
                .contentShape(RoundedRectangle(cornerRadius: style.radius))
                .opacity(configuration.isPressed ? 0.78 : 1)
                .onHover { hovering = $0 }
        }
    }
}

struct HaroldMark: View {
    var size: CGFloat
    var prominent = false

    private static let icon = Bundle.main.url(forResource: "Harold", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        Group {
            if let icon = Self.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(1.18)
            } else {
                Circle().fill(
                    RadialGradient(colors: [.orange, .red, .black], center: .center,
                                   startRadius: 0, endRadius: size / 2)
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(prominent ? 0.24 : 0.14), radius: prominent ? 13 : 4, y: 3)
        .accessibilityHidden(true)
    }
}

struct WindowGlass: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> Backdrop {
        let view = Backdrop()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: Backdrop, context: Context) {
        view.reduceTransparency = reduceTransparency
        view.updateWindow()
    }

    final class Backdrop: NSVisualEffectView {
        var reduceTransparency = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateWindow()
        }

        func updateWindow() {
            window?.isOpaque = reduceTransparency
            window?.backgroundColor = reduceTransparency ? NSColor(Palette.background) : .clear
            alphaValue = reduceTransparency ? 0 : 0.38
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

struct WorkspaceBackdrop: View {
    var body: some View {
        RadialGradient(
            colors: [Palette.mist.opacity(0.45), Palette.background.opacity(0.12)],
            center: UnitPoint(x: 0.50, y: 0.19), startRadius: 15, endRadius: 440
        )
        .mask {
            LinearGradient(stops: [.init(color: .white, location: 0.45), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 360)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SmallLabel: View {
    let text: String
    var color = Palette.muted

    var body: some View {
        Text(text.uppercased())
            .font(.harold(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
    }
}
