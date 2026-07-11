import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var showReasoning = false
    @State private var showToolCalls = false

    var body: some View {
        HStack {
            switch message.role {
            case .user:
                Spacer(minLength: 60); userBubble
            case .assistant:
                assistantBubble; Spacer(minLength: 60)
            case .system:
                systemBubble
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content).padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.accentTeal).foregroundColor(.white)
                .cornerRadius(18).cornerRadius(4, corners: [.bottomRight])
            Text(message.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
        }
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "brain.head.profile").font(.caption).foregroundColor(.accentTeal)
                Text("Assistant").font(.caption).fontWeight(.semibold).foregroundColor(.accentTeal)
            }
            if let reasoning = message.reasoning, !reasoning.isEmpty {
                Button(action: { showReasoning.toggle() }) {
                    HStack {
                        Image(systemName: showReasoning ? "chevron.down" : "chevron.right").font(.caption)
                        Text("Reasoning").font(.caption); Spacer()
                    }.foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.systemGray5)).cornerRadius(8)
                }
                if showReasoning { Text(reasoning).font(.caption).foregroundColor(.secondary).padding(8).background(Color(.systemGray6)).cornerRadius(8) }
            }
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                Button(action: { showToolCalls.toggle() }) {
                    HStack {
                        Image(systemName: showToolCalls ? "chevron.down" : "chevron.right").font(.caption)
                        Text("Tools Used (\(toolCalls.count))").font(.caption); Spacer()
                    }.foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.systemGray5)).cornerRadius(8)
                }
                if showToolCalls {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(toolCalls) { call in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Image(systemName: "wrench.fill").font(.caption2); Text(call.tool).font(.caption).fontWeight(.medium) }
                                if let result = call.result { Text(result).font(.caption2).foregroundColor(.secondary).lineLimit(3) }
                            }.padding(8).background(Color(.systemGray6)).cornerRadius(8)
                        }
                    }
                }
            }
            Text(message.content).padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemGray6)).foregroundColor(.primary)
                .cornerRadius(18).cornerRadius(4, corners: [.bottomLeft])
            if message.isStreaming {
                HStack(spacing: 4) { DotView(); DotView(delay: 0.3); DotView(delay: 0.6) }
            }
            Text(message.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
        }
    }

    private var systemBubble: some View {
        Text(message.content).font(.caption).foregroundColor(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.systemGray6)).cornerRadius(12)
    }
}

struct DotView: View {
    let delay: Double
    @State private var opacity: Double = 0.3
    init(delay: Double = 0) { self.delay = delay }

    var body: some View {
        Circle().fill(Color.accentTeal).frame(width: 6, height: 6).opacity(opacity)
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever().delay(delay)) { opacity = 1.0 } }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

#Preview {
    VStack {
        ChatBubbleView(message: ChatMessage(id: "1", role: .user, content: "Hello!", timestamp: Date(), isStreaming: false))
        ChatBubbleView(message: ChatMessage(id: "2", role: .assistant, content: "Hi!", timestamp: Date(), reasoning: "Thinking...", toolCalls: [ToolCallInfo(id: "t1", tool: "search", args: [:], result: "done")], isStreaming: false))
    }.padding()
}