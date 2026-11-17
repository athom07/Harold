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
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(fill.opacity(reduceTransparency ? 1 : 0.52))
                    }
            }
            .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(border).allowsHitTesting(false) }
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

struct Spark: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.midX
        let y = rect.midY
        let w = rect.width / 2
        let h = rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: x, y: y - h))
        path.addQuadCurve(to: CGPoint(x: x + w, y: y), control: CGPoint(x: x + w * 0.23, y: y - h * 0.20))
        path.addQuadCurve(to: CGPoint(x: x, y: y + h), control: CGPoint(x: x + w * 0.23, y: y + h * 0.20))
        path.addQuadCurve(to: CGPoint(x: x - w, y: y), control: CGPoint(x: x - w * 0.23, y: y + h * 0.20))
        path.addQuadCurve(to: CGPoint(x: x, y: y - h), control: CGPoint(x: x - w * 0.23, y: y - h * 0.20))
        path.closeSubpath()
        return path
    }
}

struct HaroldMark: View {
    var size: CGFloat
    var prominent = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.23)
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [Palette.rgb(0x247D82), Palette.accent, Palette.rgb(0x05353B)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            Canvas { context, size in
                var fold = Path()
                fold.move(to: .zero)
                fold.addLine(to: CGPoint(x: size.width, y: size.height))
                fold.addLine(to: CGPoint(x: 0, y: size.height))
                fold.closeSubpath()
                context.fill(fold, with: .color(Palette.rgb(0x043A41).opacity(0.70)))
            }
            Spark()
                .fill(LinearGradient(colors: [.white, Palette.mint], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.43, height: size * 0.49)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(0.21)).allowsHitTesting(false) }
        .shadow(color: Palette.accent.opacity(prominent ? 0.23 : 0.10), radius: prominent ? 20 : 5, y: prominent ? 9 : 2)
        .accessibilityHidden(true)
    }
}

struct WorkspaceBackdrop: View {
    var body: some View {
        RadialGradient(
            colors: [Palette.mist, Palette.background],
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
