import SwiftUI

extension Color {
    // Accent colors
    static let accentTeal = Color(red: 0.0, green: 0.78, blue: 0.74)
    static let accentBlue = Color(red: 0.2, green: 0.52, blue: 0.96)

    // Theme yellow (matches web app #f0b100)
    static let themeYellow = Color(red: 0.941, green: 0.694, blue: 0.0)
    static let themeYellowLight = Color(red: 0.992, green: 0.780, blue: 0.0)

    // Chat bubble colors
    static let userBubble = Color.accentTeal.opacity(0.85)
    static let aiBubble = Color(.systemGray6)
    static let aiBubbleDark = Color(.systemGray5)

    // Status colors
    static let statusOnline = Color.green
    static let statusOffline = Color.gray
    static let statusRunning = Color.blue
    static let statusError = Color.red

    // Card backgrounds
    static let cardBackground = Color(.systemGray6)
    static let cardBackgroundDark = Color(.systemGray5)

    // Reasoning / tool call backgrounds
    static let reasoningBackground = Color(.systemGray5).opacity(0.5)
    static let toolCallBackground = Color(.systemGray5).opacity(0.3)

    // Theme overrides
    static let launchScreenBackground = Color(.systemBackground)
}