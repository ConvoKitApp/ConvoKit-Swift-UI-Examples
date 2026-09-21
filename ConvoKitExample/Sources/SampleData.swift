import ConvoKit
import UIKit

enum SampleData {
    static let now = Date(timeIntervalSince1970: 1_788_528_000)
    static let maya = Participant(id: "member_maya", appUserId: "maya", name: "Maya Chen", role: "READ_WRITE", lastReadAt: now)
    static let alex = Participant(id: "member_alex", appUserId: "alex", name: "Alex Rivera", role: "READ_WRITE", lastReadAt: now.addingTimeInterval(-20))
    static let sam = Participant(id: "member_sam", appUserId: "sam", name: "Sam Patel", role: "READ_WRITE", lastReadAt: now.addingTimeInterval(-300))

    static let launch = Conversation(
        id: "launch-room", title: "Launch room", appId: "demo", displayTitle: "Launch room",
        description: "Release coordination", participants: [maya, alex, sam],
        createdAt: now.addingTimeInterval(-86_400), updatedAt: now
    )
    static let support = Conversation(
        id: "support-room", title: "Customer support", appId: "demo", displayTitle: "Customer support",
        description: "Priority inbox", participants: [maya, alex],
        createdAt: now.addingTimeInterval(-172_800), updatedAt: now.addingTimeInterval(-120)
    )
    static let design = Conversation(
        id: "design-room", title: "Design review", appId: "demo", displayTitle: "Design review",
        description: "New onboarding flow", participants: [maya, sam],
        createdAt: now.addingTimeInterval(-259_200), updatedAt: now.addingTimeInterval(-1_800)
    )
    static let incident = Conversation(
        id: "incident-room", title: "Incident response", appId: "demo", displayTitle: "Incident response",
        description: "API status and customer updates", participants: [maya, alex, sam],
        createdAt: now.addingTimeInterval(-345_600), updatedAt: now.addingTimeInterval(-7_200)
    )
    static let research = Conversation(
        id: "research-room", title: "User research", appId: "demo", displayTitle: "User research",
        description: "September interview notes", participants: [maya, alex],
        createdAt: now.addingTimeInterval(-432_000), updatedAt: now.addingTimeInterval(-86_400)
    )

    static let conversations = [launch, support, design, incident, research]
    static let messages = [
        Message(id: "m1", conversationId: launch.id, senderId: alex.appUserId, text: "The new onboarding is ready for review.", createdAt: now.addingTimeInterval(-420)),
        Message(id: "m2", conversationId: launch.id, senderId: maya.appUserId, text: "Looks great. I added the latest product shot.", media: [.image(name: "onboarding.png", url: "https://cdn.example.com/onboarding.png", size: 184_320)], createdAt: now.addingTimeInterval(-300)),
        Message(id: "m3", conversationId: launch.id, senderId: sam.appUserId, text: "Sharing the launch checklist too.", media: [.file(name: "launch-checklist.pdf", url: "https://cdn.example.com/launch-checklist.pdf", size: 923_000)], createdAt: now.addingTimeInterval(-180)),
        Message(id: "m4", conversationId: launch.id, senderId: maya.appUserId, text: "Perfect. We are cleared for Friday.", createdAt: now.addingTimeInterval(-40)),
    ]

    /// Inbox summaries as `listInbox` would return them for Maya: the newest message, her unread count and read position, her private
    /// mark-unread state (`unreadMarkedAt`, `privateStateVersion`, `isUnread`) and the activity time that orders the list. The research room
    /// is read (count 0) but marked unread, so the default row renders the numberless dot instead of a badge.
    static let summaries: [String: InboxSummary] = [
        launch.id: summary(latest: messages[3], read: true),
        support.id: summary(latest: Message(id: "m5", conversationId: support.id, senderId: alex.appUserId, text: "Can you confirm the refund went through?", createdAt: now.addingTimeInterval(-120)), unread: 2),
        design.id: summary(latest: Message(id: "m6", conversationId: design.id, senderId: sam.appUserId, media: [.image(name: "onboarding-v2.png", url: "https://cdn.example.com/onboarding-v2.png", size: 204_800)], createdAt: now.addingTimeInterval(-1_800)), unread: 1),
        incident.id: summary(latest: Message(id: "m7", conversationId: incident.id, senderId: alex.appUserId, text: "Status page updated. Monitoring for another 30 minutes.", createdAt: now.addingTimeInterval(-7_200)), unread: 120),
        research.id: summary(latest: Message(id: "m8", conversationId: research.id, senderId: maya.appUserId, media: [.file(name: "interview-notes.pdf", url: "https://cdn.example.com/interview-notes.pdf", size: 512_000)], createdAt: now.addingTimeInterval(-86_400)), read: true, markedUnread: true),
    ]

    /// `markedUnread` stamps the private marker (version 1, marked ten minutes ago); `isUnread` follows the wire rule
    /// `unreadCount > 0 || unreadCountCapped || unreadMarkedAt != nil` and the count stays what it is.
    private static func summary(latest: Message, unread: Int = 0, read: Bool = false, markedUnread: Bool = false) -> InboxSummary {
        let unreadMarkedAt = markedUnread ? now.addingTimeInterval(-600) : nil
        return InboxSummary(
            latestMessage: latest, unreadCount: unread,
            readPosition: read ? ReadPosition(messageId: latest.id, createdAt: latest.createdAt) : nil, lastReadAt: read ? now : nil,
            activityAt: latest.createdAt,
            unreadMarkedAt: unreadMarkedAt, privateStateVersion: markedUnread ? 1 : 0, isUnread: unread > 0 || unreadMarkedAt != nil
        )
    }

    static func imageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 520))
        return renderer.pngData { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.12, green: 0.08, blue: 0.35, alpha: 1).cgColor, UIColor(red: 0.55, green: 0.25, blue: 0.95, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 800, y: 520), options: [])
            let style = NSMutableParagraphStyle(); style.alignment = .center
            ("CONVOKIT\nSHIP CHAT, NOT INFRA" as NSString).draw(in: CGRect(x: 80, y: 180, width: 640, height: 180), withAttributes: [
                .font: UIFont.systemFont(ofSize: 42, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: style,
            ])
        }
    }
}
