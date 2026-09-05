import ConvoKit
import ConvoKitUI
import SwiftUI
import UIKit

struct DemoRootView: View {
    @State private var mode: DemoMode

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let raw = arguments.first { $0.hasPrefix("--mode=") }?.replacingOccurrences(of: "--mode=", with: "")
        _mode = State(initialValue: DemoMode(rawValue: raw ?? "standard") ?? .standard)
    }

    var body: some View {
        TabView(selection: $mode) {
            StandardComponentsView()
                .tabItem { Label(DemoMode.standard.title, systemImage: DemoMode.standard.icon) }
                .tag(DemoMode.standard)

            BrandedConversationView()
                .tabItem { Label(DemoMode.branded.title, systemImage: DemoMode.branded.icon) }
                .tag(DemoMode.branded)

            CompactConversationView()
                .tabItem { Label(DemoMode.compact.title, systemImage: DemoMode.compact.icon) }
                .tag(DemoMode.compact)

            NavigationView {
                LiveChatView()
                    .navigationTitle("Join a room")
            }
            .navigationViewStyle(.stack)
            .tabItem { Label(DemoMode.live.title, systemImage: DemoMode.live.icon) }
            .tag(DemoMode.live)
        }
        .tint(.blue)
    }
}

enum DemoMode: String, CaseIterable, Identifiable {
    case standard, branded, compact, live

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: "Chats"
        case .branded: "Support"
        case .compact: "Ops"
        case .live: "Live"
        }
    }
    var icon: String {
        switch self {
        case .standard: "bubble.left.and.bubble.right"
        case .branded: "headphones"
        case .compact: "rectangle.3.group"
        case .live: "bolt.horizontal.circle"
        }
    }
}

struct StandardComponentsView: View {
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationView {
            ConversationListView(
                conversations: SampleData.conversations,
                selectedConversationId: selectedConversation?.id,
                onSelect: { selectedConversation = $0 }
            )
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New conversation")
                }
            }
            .background(navigationLink)
        }
        .navigationViewStyle(.stack)
    }

    private var navigationLink: some View {
        NavigationLink(
            isActive: Binding(
                get: {
                    if case .some = selectedConversation { return true }
                    return false
                },
                set: { if !$0 { selectedConversation = nil } }
            )
        ) {
            Group {
                if let selectedConversation {
                    NativeConversationScreen(conversation: selectedConversation)
                }
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }
}

private struct NativeConversationScreen: View {
    let conversation: Conversation

    var body: some View {
        ConversationView(
            conversation: conversation,
            messages: SampleData.messages,
            currentUserId: "maya",
            readAtByUserId: ["alex": SampleData.now],
            configuration: .init(showsHeader: false),
            onSendMessage: { _ in true },
            mediaDataProvider: { _ in SampleData.imageData() }
        )
        .navigationTitle(conversation.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Conversation details")
            }
        }
    }
}

struct BrandedConversationView: View {
    private let theme = ConvoKitTheme(
        accent: .indigo,
        incomingBubble: Color(uiColor: .secondarySystemBackground),
        outgoingBubble: .indigo,
        cornerRadius: 18
    )

    var body: some View {
        NavigationView {
            ConversationView(
                conversation: SampleData.support,
                messages: SampleData.messages,
                currentUserId: "maya",
                typingUserIds: ["alex"],
                readAtByUserId: ["alex": SampleData.now],
                configuration: .init(showsHeader: false, composerPlaceholder: "Reply to the customer"),
                onSendMessage: { _ in true },
                mediaDataProvider: { _ in SampleData.imageData() }
            )
            .convoKitTheme(theme)
            .navigationTitle("Customer support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Label("Online", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("View customer", systemImage: "person") {}
                        Button("Conversation details", systemImage: "info.circle") {}
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .tint(.indigo)
    }
}

struct CompactConversationView: View {
    var body: some View {
        NavigationView {
            ConversationView(
                conversation: SampleData.launch,
                messages: SampleData.messages,
                currentUserId: "maya",
                readAtByUserId: ["alex": SampleData.now],
                configuration: .init(
                    showsHeader: false,
                    showsAvatars: false,
                    showsTimestamps: false,
                    showsReadReceipts: true,
                    messageMaxWidth: 320,
                    composerPlaceholder: "Message operations"
                ),
                onSendMessage: { _ in true },
                mediaDataProvider: { _ in SampleData.imageData() },
                messageView: { context in AnyView(OperationsMessageRow(context: context)) }
            )
            .convoKitDensity(.compact)
            .navigationTitle("Launch operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Label("Details", systemImage: "info.circle")
                    }
                    .accessibilityLabel("Room details")
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct OperationsMessageRow: View {
    let context: MessageContext

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(context.isCurrentUser ? "You" : firstName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(context.message.text ?? context.message.media.first?.name ?? "Attachment")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !context.readerIds.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Read")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var firstName: String {
        context.sender?.name.components(separatedBy: " ").first ?? context.message.senderId
    }
}
