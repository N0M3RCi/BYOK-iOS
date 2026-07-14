import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentTeal
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(color).cornerRadius(12).opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct EmptyStateView: View {
    let icon: String; let title: String; let message: String?
    init(icon: String, title: String, message: String? = nil) { self.icon = icon; self.title = title; self.message = message }
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(.secondary)
            Text(title).font(.headline).foregroundColor(.secondary)
            if let m = message { Text(m).font(.subheadline).foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

@MainActor
enum HapticFeedback {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}