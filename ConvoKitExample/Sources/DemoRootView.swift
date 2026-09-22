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
/// `useShowcaseRoom` does. It holds the whole fixture history but renders one
/// WINDOW of it, because that is what makes a jump worth having: the row a
/// reply quotes can sit outside the window, and bringing it on screen is what
/// `getMessageContext` does against the backend.
///
/// `messages` is the rendered window, `editingMessage` the snapshot being
/// edited, `replyTarget` the row the next send quotes, and `replyPreviews` the
/// quoted messages keyed by the id that points at them — derived from the
/// window when it already holds the quoted row, taken from the fixture batch
/// when it does not, and the terminal `.unavailable` once the quoted row is
/// gone. A save bumps that row's `revision` and refreshes any quote of it, a
/// delete drops the row while every reply to it keeps its reference, and a
/// jump replaces the window, centres the target and flashes it for about two
/// seconds. Each screen owns one instance and hands its members to
/// `ConversationView`, so the package's default rows and composer (Chats,
/// Support) and the host-rendered `OperationsMessageRow` (Ops) all exercise
/// the reply, quote and jump surfaces without the backend.
@MainActor
final class ShowcaseRoom: ObservableObject {
    /// Rows per window, standing in for a store's `messagePageSize`.
    private static let pageSize = 5

    @Published private(set) var messages: [Message] = []
    @Published private(set) var editingMessage: Message?
    @Published private(set) var replyTarget: Message?
    @Published private(set) var replyPreviews: [String: ReplyPreviewState] = [:]
    @Published private(set) var highlightedMessageId: String?
    @Published private(set) var scrollTarget: String?
    @Published private(set) var hasOlderMessages = false
    @Published private(set) var hasNewerMessages = false
    /// True while the window is the one a jump installed instead of the newest
    /// rows; the view shows "Load newer messages" and "Jump to latest" then.
    @Published private(set) var isJumped = false

    private var history = SampleData.messages
    private var start = 0
    private var end = 0
    private var flash: Task<Void, Never>?
    private var sent = 0

    init() {
        replyPreviews = SampleData.quotedPreviews.mapValues { .resolved($0) }
        // The batch answered and this id was not in it, which is the only
        // signal a deleted quoted message ever gets.
        replyPreviews[SampleData.removedQuotedMessageId] = .unavailable
        showNewest()
    }

    // MARK: Window

    /// The newest page, following new rows: the mode a room opens in.
    private func showNewest() {
        end = history.count
        start = max(0, end - Self.pageSize)
        isJumped = false
        refreshWindow()
    }

    private func refreshWindow() {
        end = min(max(0, end), history.count)
        start = min(max(0, start), end)
        messages = Array(history[start..<end])
        hasOlderMessages = start > 0
        hasNewerMessages = end < history.count
        resolvePreviews()
    }

    func loadOlder() {
        guard start > 0 else { return }
        start = max(0, start - Self.pageSize)
        refreshWindow()
    }

    /// Pages the newer edge of a jumped window. Reaching the newest row is not
    /// flipped in place: it returns to the latest through the same path the
    /// "Jump to latest" control uses.
    func loadNewer() {
        guard isJumped else { return }
        end = min(history.count, end + Self.pageSize)
        if end == history.count { returnToLatest() } else { refreshWindow() }
    }

    /// Drops the jumped window and reloads the newest page. The highlight is
    /// carried through, so the target re-anchors when it is still on screen.
    func returnToLatest() {
        showNewest()
        if let highlighted = highlightedMessageId, messages.contains(where: { $0.id == highlighted }) { scrollTarget = highlighted }
    }

    // MARK: Jumping

    /// A row the window already holds is only highlighted and scrolled to. A
    /// row it does not hold replaces the window with one centred on it. An id
    /// the room no longer has is the answer a deleted quoted message gives:
    /// the window is untouched and the quote becomes terminally unavailable.
    func jump(to messageId: String) {
        guard let index = history.firstIndex(where: { $0.id == messageId }) else {
            markUnavailable(messageId)
            return
        }
        if !messages.contains(where: { $0.id == messageId }) {
            start = max(0, index - Self.pageSize / 2)
            end = min(history.count, start + Self.pageSize)
            isJumped = end < history.count
            refreshWindow()
        }
        highlight(messageId)
    }

    /// The ~2 s flash plus the one-shot scroll target the view consumes
    /// through `scrollTargetHandled()`.
    private func highlight(_ messageId: String) {
        highlightedMessageId = messageId
        scrollTarget = messageId
        flash?.cancel()
        flash = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self, self.highlightedMessageId == messageId else { return }
            self.flash = nil
            self.highlightedMessageId = nil
        }
    }

    /// The view reports that it has scrolled to `scrollTarget`, which clears it.
    func scrollTargetHandled() { scrollTarget = nil }

    // MARK: Replying

    /// Replying and editing are mutually exclusive, so starting one ends the other.
    func startReply(_ message: Message) {
        editingMessage = nil
        replyTarget = message
    }

    func cancelReply() { replyTarget = nil }

    /// Appends the sent row the way an optimistic send does: the quoted id is
    /// stamped on the row itself, so its quoted block renders straight away,
    /// and the reply target is dropped only once the row exists. A send while
    /// jumped returns to the latest first, so a sent row can never land
    /// outside the rendered window.
    func send(_ text: String) -> Bool {
        if isJumped { showNewest() }
        sent += 1
        history.append(Message(
            id: "local-\(sent)", conversationId: SampleData.launch.id, senderId: SampleData.maya.appUserId,
            text: text, createdAt: Date(), revision: 0, replyToMessageId: replyTarget?.id
        ))
        replyTarget = nil
        end = history.count
        isJumped = false
        refreshWindow()
        return true
    }

    // MARK: Editing and deleting

    func edit(_ message: Message) {
        replyTarget = nil
        editingMessage = message
    }

    func cancelEditing() { editingMessage = nil }

    func saveEdit(_ text: String) -> Bool {
        guard let editing = editingMessage, let index = history.firstIndex(where: { $0.id == editing.id }) else { return false }
        let current = history[index]
        history[index] = Message(
            id: current.id, conversationId: current.conversationId, senderId: current.senderId,
            text: text.isEmpty ? nil : text, media: current.media, createdAt: current.createdAt,
            updatedAt: Date(), clientMessageId: current.clientMessageId, revision: current.revision + 1,
            // An edit never changes what a reply points at.
            replyToMessageId: current.replyToMessageId
        )
        editingMessage = nil
        refreshWindow()
        // A quote is re-read, never copied: the edited text reaches every reply
        // that points at this row, including one whose window no longer holds it.
        refreshQuote(of: history[index])
        return true
    }

    func delete(_ message: Message) -> Bool {
        history.removeAll { $0.id == message.id }
        if editingMessage?.id == message.id { editingMessage = nil }
        if replyTarget?.id == message.id { replyTarget = nil }
        // Every reply to it keeps its reference and its jump affordance; only
        // the quoted text becomes unavailable, and that is terminal.
        markUnavailable(message.id)
        refreshWindow()
        return true
    }

    // MARK: Quoted previews

    /// One pass per window change, never one per row: a quoted row the window
    /// already holds is derived locally and costs no request, which is what
    /// the store does before it asks the backend for the rest.
    private func resolvePreviews() {
        for message in messages {
            guard let quoted = message.replyToMessageId, replyPreviews[quoted] != .unavailable,
                  let parent = messages.first(where: { $0.id == quoted }) else { continue }
            replyPreviews[quoted] = .resolved(Self.preview(of: parent))
        }
    }

    private func refreshQuote(of message: Message) {
        guard let state = replyPreviews[message.id], state != .unavailable else { return }
        replyPreviews[message.id] = .resolved(Self.preview(of: message))
    }

    /// Written only for an id a rendered row quotes or one already cached, so
    /// the map stays bounded by the window.
    private func markUnavailable(_ messageId: String) {
        guard replyPreviews[messageId] != nil || messages.contains(where: { $0.replyToMessageId == messageId }) else { return }
        replyPreviews[messageId] = .unavailable
    }

    private static func preview(of message: Message) -> ReplyPreview {
        let truncated = (message.text?.count ?? 0) > 500
        return ReplyPreview(
            id: message.id, conversationId: message.conversationId, senderId: message.senderId,
            text: message.text.map { String($0.prefix(500)) }, textTruncated: truncated,
            createdAt: message.createdAt, revision: message.revision, mediaCount: message.media.count
        )
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
/// `Delete message` accessibility actions, every member's row gets `Reply`,
/// a reply shows the quoted block that jumps to the message it quotes, and
/// the composer switches to edit mode or shows the cancellable reply strip.
private struct NativeConversationScreen: View {
    let conversation: Conversation
    @StateObject private var room = ShowcaseRoom()

    var body: some View {
        ConversationView(
            conversation: conversation,
            messages: room.messages,
            currentUserId: "maya",
            readAtByUserId: ["alex": SampleData.now],
            hasOlderMessages: room.hasOlderMessages,
            configuration: .init(showsHeader: false),
            onSendMessage: { room.send($0) },
            onLoadOlder: { room.loadOlder() },
            mediaDataProvider: { _ in SampleData.imageData() },
            editingMessage: room.editingMessage,
            onEditMessage: { room.edit($0) },
            onCancelEditing: { room.cancelEditing() },
            onSaveEdit: { room.saveEdit($0) },
            onDeleteMessage: { room.delete($0) },
            replyTarget: room.replyTarget,
            onReplyToMessage: { room.startReply($0) },
            onCancelReply: { room.cancelReply() },
            replyPreviewByMessageId: room.replyPreviews,
            onJumpToMessage: { room.jump(to: $0) },
            highlightedMessageId: room.highlightedMessageId,
            scrollTarget: room.scrollTarget,
            onScrollTargetHandled: { room.scrollTargetHandled() },
            hasNewerMessages: room.hasNewerMessages,
            onLoadNewer: { room.loadNewer() },
            onReturnToLatest: { room.returnToLatest() }
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
    /// `highlight` is the flash behind the row a jump lands on. It follows
    /// `accent` at low opacity until it is set, so branding it is optional.
    private let theme: ConvoKitTheme = {
        var value = ConvoKitTheme(
            accent: .indigo,
            incomingBubble: Color(uiColor: .secondarySystemBackground),
            outgoingBubble: .indigo,
            cornerRadius: 18
        )
        value.highlight = Color.indigo.opacity(0.22)
        return value
    }()
    @StateObject private var room = ShowcaseRoom()

    var body: some View {
        NavigationView {
            ConversationView(
                conversation: SampleData.support,
                messages: room.messages,
                currentUserId: "maya",
                typingUserIds: ["alex"],
                readAtByUserId: ["alex": SampleData.now],
                hasOlderMessages: room.hasOlderMessages,
                configuration: .init(showsHeader: false, composerPlaceholder: "Reply to the customer"),
                onSendMessage: { room.send($0) },
                onLoadOlder: { room.loadOlder() },
                mediaDataProvider: { _ in SampleData.imageData() },
                editingMessage: room.editingMessage,
                onEditMessage: { room.edit($0) },
                onCancelEditing: { room.cancelEditing() },
                onSaveEdit: { room.saveEdit($0) },
                onDeleteMessage: { room.delete($0) },
                replyTarget: room.replyTarget,
                onReplyToMessage: { room.startReply($0) },
                onCancelReply: { room.cancelReply() },
                replyPreviewByMessageId: room.replyPreviews,
                onJumpToMessage: { room.jump(to: $0) },
                highlightedMessageId: room.highlightedMessageId,
                scrollTarget: room.scrollTarget,
                onScrollTargetHandled: { room.scrollTargetHandled() },
                hasNewerMessages: room.hasNewerMessages,
                onLoadNewer: { room.loadNewer() },
                onReturnToLatest: { room.returnToLatest() }
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
                hasOlderMessages: room.hasOlderMessages,
                configuration: .init(
                    showsHeader: false,
                    showsAvatars: false,
                    showsTimestamps: false,
                    showsReadReceipts: true,
                    messageMaxWidth: 320,
                    composerPlaceholder: "Message operations"
                ),
                onSendMessage: { room.send($0) },
                onLoadOlder: { room.loadOlder() },
                mediaDataProvider: { _ in SampleData.imageData() },
                messageView: { context in AnyView(OperationsMessageRow(context: context)) },
                editingMessage: room.editingMessage,
                onEditMessage: { room.edit($0) },
                onCancelEditing: { room.cancelEditing() },
                onSaveEdit: { room.saveEdit($0) },
                onDeleteMessage: { room.delete($0) },
                replyTarget: room.replyTarget,
                onReplyToMessage: { room.startReply($0) },
                onCancelReply: { room.cancelReply() },
                replyPreviewByMessageId: room.replyPreviews,
                onJumpToMessage: { room.jump(to: $0) },
                highlightedMessageId: room.highlightedMessageId,
                scrollTarget: room.scrollTarget,
                onScrollTargetHandled: { room.scrollTargetHandled() },
                hasNewerMessages: room.hasNewerMessages,
                onLoadNewer: { room.loadNewer() },
                onReturnToLatest: { room.returnToLatest() }
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
/// package's "Delete this message?" confirmation before deleting. `Reply` is
/// offered on `context.canReply`, which drops the own-row term because any
/// member may quote any row, and a reply renders its own quoted line from
/// `context.replyPreview` — resolved, terminally unavailable, or not yet
/// resolved, which is the reference with no quoted text and never the
/// unavailable wording. The package applies the jump flash to whatever this
/// builder returns, so the highlight needs nothing here.
private struct OperationsMessageRow: View {
    let context: MessageContext

    @ViewBuilder var body: some View {
        if context.canEdit || context.canDelete || context.canReply {
            row.contextMenu {
                if let edit = context.edit {
                    Button { edit() } label: { Label("Edit message", systemImage: "pencil") }
                }
                if let remove = context.remove {
                    Button(role: .destructive) { Task { _ = await remove() } } label: { Label("Delete message", systemImage: "trash") }
                }
                if let reply = context.reply {
                    Button { reply() } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
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
            VStack(alignment: .leading, spacing: 3) {
                if context.message.replyToMessageId != nil { quoted }
                Text(context.message.text ?? context.message.media.first?.name ?? "Attachment")
                    .font(.subheadline)
            }
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

    /// The quoted line, activating `jumpToReplyTarget` when the view can jump.
    /// A quoted message that is gone keeps the reference and the jump: only
    /// the text is unavailable.
    @ViewBuilder private var quoted: some View {
        let label = quotedText
        if let jump = context.jumpToReplyTarget {
            Button { jump() } label: { quotedLine(label) }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
        } else {
            quotedLine(label)
        }
    }

    private func quotedLine(_ label: String) -> some View {
        Label(label, systemImage: "arrowshape.turn.up.left")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var quotedText: String {
        if case .resolved(let preview)? = context.replyPreview {
            if let text = preview.text, !text.isEmpty { return preview.textTruncated ? text + "…" : text }
            return preview.mediaCount == 1 ? "Attachment" : "\(preview.mediaCount) attachments"
        }
        return context.replyPreview == .unavailable ? "Original message unavailable" : "Quoted message"
    }

    private var firstName: String {
        context.sender?.name.components(separatedBy: " ").first ?? context.message.senderId
    }
}
