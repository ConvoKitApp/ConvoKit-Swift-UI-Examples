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

/// The fixture room behind the three offline controlled screens (Chats,
/// Support, Ops), standing in for a room store the way the React showcase's
/// `useShowcaseRoom` does: `messages` is the local history, `editingMessage`
/// is the snapshot being edited, `saveEdit` bumps that literal's `revision`
/// (as the backend does on every content edit) and `delete` drops the row.
/// Each screen owns one instance and hands its members to `ConversationView`,
/// so the package's default rows and composer (Chats, Support) and the
/// host-rendered `OperationsMessageRow` (Ops) all exercise the edit surface
/// without the backend.
@MainActor
final class ShowcaseRoom: ObservableObject {
    @Published var messages = SampleData.messages
    @Published var editingMessage: Message?

    func edit(_ message: Message) { editingMessage = message }
    func cancelEditing() { editingMessage = nil }

    func saveEdit(_ text: String) -> Bool {
        guard let editing = editingMessage, let index = messages.firstIndex(where: { $0.id == editing.id }) else { return false }
        let current = messages[index]
        messages[index] = Message(
            id: current.id, conversationId: current.conversationId, senderId: current.senderId,
            text: text.isEmpty ? nil : text, media: current.media, createdAt: current.createdAt,
            updatedAt: Date(), clientMessageId: current.clientMessageId, revision: current.revision + 1
        )
        editingMessage = nil
        return true
    }

    func delete(_ message: Message) -> Bool {
        messages.removeAll { $0.id == message.id }
        if editingMessage?.id == message.id { editingMessage = nil }
        return true
    }
}

struct StandardComponentsView: View {
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationView {
            ConversationListView(
                conversations: SampleData.conversations,
                selectedConversationId: selectedConversation?.id,
                summaries: SampleData.summaries,
                currentUserId: "maya",
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

/// The package's default rows and composer over the fixture room: Maya's
/// confirmed rows get the context menu and the `Edit message` /
/// `Delete message` accessibility actions, and the composer's edit mode.
private struct NativeConversationScreen: View {
    let conversation: Conversation
    @StateObject private var room = ShowcaseRoom()

    var body: some View {
        ConversationView(
            conversation: conversation,
            messages: room.messages,
            currentUserId: "maya",
            readAtByUserId: ["alex": SampleData.now],
            configuration: .init(showsHeader: false),
            onSendMessage: { _ in true },
            mediaDataProvider: { _ in SampleData.imageData() },
            editingMessage: room.editingMessage,
            onEditMessage: { room.edit($0) },
            onCancelEditing: { room.cancelEditing() },
            onSaveEdit: { room.saveEdit($0) },
            onDeleteMessage: { room.delete($0) }
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
    @StateObject private var room = ShowcaseRoom()

    var body: some View {
        NavigationView {
            ConversationView(
                conversation: SampleData.support,
                messages: room.messages,
                currentUserId: "maya",
                typingUserIds: ["alex"],
                readAtByUserId: ["alex": SampleData.now],
                configuration: .init(showsHeader: false, composerPlaceholder: "Reply to the customer"),
                onSendMessage: { _ in true },
                mediaDataProvider: { _ in SampleData.imageData() },
                editingMessage: room.editingMessage,
                onEditMessage: { room.edit($0) },
                onCancelEditing: { room.cancelEditing() },
                onSaveEdit: { room.saveEdit($0) },
                onDeleteMessage: { room.delete($0) }
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

/// The controlled `ConversationView` with host-rendered rows over the same
/// fixture room, so `OperationsMessageRow` can offer the package's `edit` /
/// `remove` context actions and the composer's edit mode runs against local
/// state.
struct CompactConversationView: View {
    @StateObject private var room = ShowcaseRoom()

    var body: some View {
        NavigationView {
            ConversationView(
                conversation: SampleData.launch,
                messages: room.messages,
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
                messageView: { context in AnyView(OperationsMessageRow(context: context)) },
                editingMessage: room.editingMessage,
                onEditMessage: { room.edit($0) },
                onCancelEditing: { room.cancelEditing() },
                onSaveEdit: { room.saveEdit($0) },
                onDeleteMessage: { room.delete($0) }
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

/// A dense host-rendered row over the package's `MessageContext`: the
/// `Edited` label follows `context.isEdited` (`revision > 0`), and the
/// context menu offers `context.edit` / `context.remove` exactly when the
/// package says the row is eligible (the viewer's own confirmed row in a
/// writable room, with the matching callback on the view). `remove` runs the
/// package's "Delete this message?" confirmation before deleting.
private struct OperationsMessageRow: View {
    let context: MessageContext

    @ViewBuilder var body: some View {
        if context.canEdit || context.canDelete {
            row.contextMenu {
                if let edit = context.edit {
                    Button { edit() } label: { Label("Edit message", systemImage: "pencil") }
                }
                if let remove = context.remove {
                    Button(role: .destructive) { Task { _ = await remove() } } label: { Label("Delete message", systemImage: "trash") }
                }
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(context.isCurrentUser ? "You" : firstName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(context.message.text ?? context.message.media.first?.name ?? "Attachment")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if context.isEdited {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Edited")
            }
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
