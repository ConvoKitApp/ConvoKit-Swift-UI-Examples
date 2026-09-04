import ConvoKit
import ConvoKitUI
import SwiftUI

struct DemoRootView: View {
    @State private var mode: DemoMode

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let raw = arguments.first { $0.hasPrefix("--mode=") }?.replacingOccurrences(of: "--mode=", with: "")
        _mode = State(initialValue: DemoMode(rawValue: raw ?? "standard") ?? .standard)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Example", selection: $mode) {
                    ForEach(DemoMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).padding(12).background(.white)
                Group {
                    switch mode {
                    case .standard: StandardComponentsView()
                    case .branded: BrandedConversationView()
                    case .compact: CompactConversationView()
                    case .live: LiveChatView()
                    }
                }
            }
            .navigationTitle("ConvoKit SwiftUI")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

enum DemoMode: String, CaseIterable, Identifiable {
    case standard, branded, compact, live
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct StandardComponentsView: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ConversationListView", systemImage: "list.bullet.rectangle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ConversationListView(conversations: SampleData.conversations, selectedConversationId: SampleData.launch.id, onSelect: { _ in })
                    .frame(height: 178).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.07)))
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("ConversationView", systemImage: "bubble.left.and.bubble.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ConversationView(
                    conversation: SampleData.launch, messages: SampleData.messages, currentUserId: "maya",
                    readAtByUserId: ["alex": SampleData.now],
                    configuration: .init(showsHeader: true, showsAvatars: true, showsTimestamps: true, showsReadReceipts: true, messageMaxWidth: 250),
                    onSendMessage: { _ in true }, mediaDataProvider: { _ in SampleData.imageData() }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.07)))
            }
        }.padding(12).background(Color(red: 0.95, green: 0.97, blue: 0.97))
    }
}

struct BrandedConversationView: View {
    private let theme = ConvoKitTheme(
        accent: Color(red: 0.48, green: 0.24, blue: 0.91),
        background: Color(red: 0.97, green: 0.95, blue: 1),
        surface: .white,
        incomingBubble: Color(red: 0.92, green: 0.88, blue: 1),
        outgoingBubble: Color(red: 0.48, green: 0.24, blue: 0.91),
        cornerRadius: 22
    )

    var body: some View {
        ConversationView(
            conversation: SampleData.support,
            messages: SampleData.messages,
            currentUserId: "maya",
            typingUserIds: ["alex"],
            readAtByUserId: ["alex": SampleData.now],
            configuration: .init(composerPlaceholder: "Reply to the customer"),
            onSendMessage: { _ in true },
            mediaDataProvider: { _ in SampleData.imageData() },
            header: { room in AnyView(
                HStack {
                    ZStack { Circle().fill(.white.opacity(0.2)); Image(systemName: "sparkles").foregroundStyle(.white) }.frame(width: 42, height: 42)
                    VStack(alignment: .leading) { Text("ACME SUPPORT").font(.caption.weight(.bold)); Text(room.displayTitle).font(.headline) }
                    Spacer(); Text("ONLINE").font(.caption2.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 5).background(.green).clipShape(Capsule())
                }.foregroundStyle(.white).padding().background(Color(red: 0.30, green: 0.12, blue: 0.65))
            ) }
        ).convoKitTheme(theme)
    }
}

struct CompactConversationView: View {
    var body: some View {
        ConversationView(
            conversation: SampleData.launch, messages: SampleData.messages, currentUserId: "maya",
            readAtByUserId: ["alex": SampleData.now],
            configuration: .init(showsHeader: true, showsAvatars: false, showsTimestamps: false, showsReadReceipts: true, messageMaxWidth: 290, composerPlaceholder: "Message ops"),
            onSendMessage: { _ in true }, mediaDataProvider: { _ in SampleData.imageData() },
            messageView: { context in AnyView(
                HStack(spacing: 8) {
                    Text(context.sender?.name.components(separatedBy: " ").first ?? context.message.senderId).font(.caption.weight(.bold)).frame(width: 42, alignment: .leading)
                    Text(context.message.text ?? context.message.media.first?.name ?? "Attachment").font(.subheadline).lineLimit(2)
                    Spacer(); if !context.readerIds.isEmpty { Image(systemName: "checkmark.done").font(.caption).foregroundStyle(.green) }
                }.padding(10).background(context.isCurrentUser ? Color.green.opacity(0.12) : Color.white).clipShape(RoundedRectangle(cornerRadius: 9))
            ) }
        )
        .convoKitDensity(.compact)
        .convoKitTheme(ConvoKitTheme(accent: .green, background: Color(red: 0.94, green: 0.96, blue: 0.94), outgoingBubble: .green, cornerRadius: 10))
    }
}
