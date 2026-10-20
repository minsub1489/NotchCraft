import SwiftUI
import NotchCraftCore

enum Theme {
    static let background = Color.black
    static let surface = Color(white: 0.025)
    static let raised = Color(white: 0.055)
    static let text = Color(hex: 0xEDEFE9)
    static let muted = Color(hex: 0x82877D)
    static let green = Color(hex: 0xA5C582)
    static let amber = Color(hex: 0xE2B36E)
    static let line = Color.white.opacity(0.09)
    static let red = Color(hex: 0xEB8A7D)
    static func status(_ state: AgentStatus) -> Color {
        switch state {
        case .working: green
        case .waitingApproval: amber
        case .failed: red
        case .completed: Color(hex: 0x88B8AA)
        default: muted
        }
    }
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
struct QuietButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? Color.black : Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(prominent ? Theme.green.opacity(configuration.isPressed ? 0.75 : 1) : Color.white.opacity(configuration.isPressed ? 0.1 : 0.045))
            .clipShape(RoundedRectangle(cornerRadius: 7)).opacity(enabled ? 1 : 0.4)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(prominent ? Color.clear : Theme.line))
    }
}
struct IconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14)).foregroundStyle(Theme.muted)
            .frame(width: 34, height: 34).background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.025))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
struct Tag: View {
    let text: String
    var color: Color = Theme.green
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 5, height: 5); Text(text).font(.system(size: 10, weight: .medium)) }
            .foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.07)).clipShape(Capsule()).overlay(Capsule().strokeBorder(color.opacity(0.16)))
    }
}
struct SectionLabel: View {
    let title: String
    var count: Int? = nil
    var body: some View {
        HStack { Text(title).font(.system(size: 12, weight: .semibold)); if let count { Text(String(count)).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted) }; Spacer() }.foregroundStyle(Theme.text)
    }
}
struct PixelAvatar: View {
    var index: Int = 0
    var size: CGFloat = 34
    var body: some View {
        Canvas { context, canvas in
            let colors: [Color] = [Color(hex: 0x7CABB8), Color(hex: 0xB894BD), Color(hex: 0x9CA968), Color(hex: 0xCB9A65), Color(hex: 0x8CA79D), Color(hex: 0xAEACAF)]
            let unit = canvas.width / 12
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)), with: .color(color))
            }
            rect(1, 1, 10, 10, Color(white: 0.08)); rect(3, 2, 6, 5, Color(hex: 0xE5BD94))
            rect(3, 1, 6, 2, colors[index % colors.count]); rect(2, 3, 1, 2, Color(hex: 0x68503E))
            rect(4, 4, 1, 1, .black); rect(7, 4, 1, 1, .black); rect(5, 6, 2, 1, Color(hex: 0x9A6A4C))
            rect(3, 8, 6, 3, colors[index % colors.count]); rect(5, 8, 2, 2, Color(hex: 0xEDE5CC))
        }.frame(width: size, height: size).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
