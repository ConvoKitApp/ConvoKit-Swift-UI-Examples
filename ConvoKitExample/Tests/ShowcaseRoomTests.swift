import ConvoKit
import ConvoKitUI
import XCTest
@testable import ConvoKitSwiftExample

/// The showcase's own room state, which is what the three offline screens
/// hand to the package's controlled `ConversationView`. The package's own
/// behaviour is covered in the package; these cover the host side of the
/// reply, quote and jump surfaces the example demonstrates.
@MainActor
final class ShowcaseRoomTests: XCTestCase {
    private func fixture(_ id: String) throws -> Message {
        try XCTUnwrap(SampleData.messages.first { $0.id == id }, "no fixture message \(id)")
    }

    private func ids(_ room: ShowcaseRoom) -> [String] { room.messages.map(\.id) }

    // MARK: The window

    func testOpensOnTheNewestPageWithOlderHistoryBehindIt() {
        let room = ShowcaseRoom()
        XCTAssertEqual(ids(room), ["m2", "m3", "m14", "m15", "m4"])
        XCTAssertTrue(room.hasOlderMessages)
        XCTAssertFalse(room.hasNewerMessages)
        XCTAssertFalse(room.isJumped)
    }

    func testLoadingOlderExtendsTheWindowBackwards() {
        let room = ShowcaseRoom()
        room.loadOlder()
        XCTAssertEqual(ids(room).first, "m10")
        XCTAssertEqual(ids(room).count, 10)
        XCTAssertTrue(room.hasOlderMessages)
        XCTAssertFalse(room.isJumped)
    }

    // MARK: Quoted previews

    func testAQuotedMessageOutsideTheWindowIsResolvedFromTheBatch() throws {
        let room = ShowcaseRoom()
        XCTAssertFalse(ids(room).contains("m11"))
        guard case .resolved(let preview)? = room.replyPreviews["m11"] else { return XCTFail("m11 should be resolved") }
        XCTAssertEqual(preview.senderId, SampleData.alex.appUserId)
        XCTAssertEqual(preview.text, try fixture("m11").text)
        XCTAssertFalse(preview.textTruncated)
    }

    func testAQuotedMessageThatIsGoneIsUnavailableAndTheReplyKeepsItsReference() throws {
        let room = ShowcaseRoom()
        XCTAssertEqual(room.replyPreviews[SampleData.removedQuotedMessageId], .unavailable)
        let reply = try XCTUnwrap(room.messages.first { $0.id == "m15" })
        XCTAssertEqual(reply.replyToMessageId, SampleData.removedQuotedMessageId)
    }

    func testDeletingAQuotedMessageKeepsEveryReplyToIt() throws {
        let room = ShowcaseRoom()
        XCTAssertTrue(room.delete(try fixture("m11")))
        XCTAssertEqual(room.replyPreviews["m11"], .unavailable)
        let reply = try XCTUnwrap(room.messages.first { $0.id == "m14" })
        XCTAssertEqual(reply.replyToMessageId, "m11")
    }

    func testDeletingAMessageNobodyQuotesCachesNothing() throws {
        let room = ShowcaseRoom()
        XCTAssertTrue(room.delete(try fixture("m4")))
        XCTAssertNil(room.replyPreviews["m4"])
    }

    func testEditingAQuotedMessageOutsideTheWindowRefreshesTheQuote() throws {
        let room = ShowcaseRoom()
        room.edit(try fixture("m11"))
        XCTAssertTrue(room.saveEdit("Rollout plan: staged release first, stores on Monday."))
        guard case .resolved(let preview)? = room.replyPreviews["m11"] else { return XCTFail("m11 should still be resolved") }
        XCTAssertEqual(preview.text, "Rollout plan: staged release first, stores on Monday.")
        XCTAssertEqual(preview.revision, 1)
    }

    func testEditingAReplyKeepsWhatItPointsAt() throws {
        let room = ShowcaseRoom()
        room.edit(try fixture("m14"))
        XCTAssertTrue(room.saveEdit("Still the plan?"))
        let reply = try XCTUnwrap(room.messages.first { $0.id == "m14" })
        XCTAssertEqual(reply.replyToMessageId, "m11")
        XCTAssertEqual(reply.revision, 1)
        XCTAssertTrue(reply.isEdited)
    }

    // MARK: Replying

    func testSendingStampsTheQuotedIdOnTheRowAndClearsTheTarget() throws {
        let room = ShowcaseRoom()
        room.startReply(try fixture("m4"))
        XCTAssertEqual(room.replyTarget?.id, "m4")
        XCTAssertTrue(room.send("On it."))
        XCTAssertNil(room.replyTarget)
        let sent = try XCTUnwrap(room.messages.last)
        XCTAssertEqual(sent.text, "On it.")
        XCTAssertEqual(sent.replyToMessageId, "m4")
    }

    func testAQuotedMessageInsideTheWindowIsDerivedWithoutABatch() throws {
        let room = ShowcaseRoom()
        XCTAssertNil(room.replyPreviews["m4"])
        room.startReply(try fixture("m4"))
        XCTAssertTrue(room.send("On it."))
        guard case .resolved(let preview)? = room.replyPreviews["m4"] else { return XCTFail("m4 should be derived") }
        XCTAssertEqual(preview.text, try fixture("m4").text)
        XCTAssertEqual(preview.mediaCount, 0)
    }

    /// The newest row is the easy case. This is the other edge: a send grows
    /// the window at its newer edge (`end`) and never moves `start`, so the
    /// OLDEST rendered row is still rendered after a reply to it, and its
    /// quote is derived from the window rather than left waiting for a batch.
    func testReplyingToTheOldestRenderedRowKeepsItRenderedAndDerivesItsQuote() throws {
        let room = ShowcaseRoom()
        let oldest = try XCTUnwrap(room.messages.first)
        XCTAssertEqual(oldest.id, "m2")
        room.startReply(oldest)
        XCTAssertTrue(room.send("On it."))
        XCTAssertEqual(ids(room), ["m2", "m3", "m14", "m15", "m4", "local-1"])
        guard case .resolved(let preview)? = room.replyPreviews["m2"] else { return XCTFail("m2 should be derived") }
        XCTAssertEqual(preview.text, try fixture("m2").text)
        XCTAssertEqual(preview.mediaCount, 1)
        XCTAssertEqual(preview.revision, 1)
    }

    /// "Not yet resolved" is the ABSENCE of an entry and never `.unavailable`:
    /// a send while jumped returns to the latest first, so a reply to a row
    /// only the jumped window held keeps its reference and the package draws
    /// the reference with no quoted text until a preview arrives for it.
    func testAQuoteTheRoomHasNotBatchedIsAbsentRatherThanUnavailable() throws {
        let room = ShowcaseRoom()
        room.jump(to: "m9")
        let quoted = try XCTUnwrap(room.messages.first { $0.id == "m9" })
        room.startReply(quoted)
        XCTAssertTrue(room.send("Picking this back up."))
        XCTAssertFalse(ids(room).contains("m9"))
        XCTAssertNil(room.replyPreviews["m9"])
        XCTAssertEqual(try XCTUnwrap(room.messages.last).replyToMessageId, "m9")
    }

    func testCancellingAReplyDropsOnlyTheTarget() throws {
        let room = ShowcaseRoom()
        let before = ids(room)
        room.startReply(try fixture("m4"))
        room.cancelReply()
        XCTAssertNil(room.replyTarget)
        XCTAssertEqual(ids(room), before)
    }

    func testReplyingAndEditingAreMutuallyExclusive() throws {
        let room = ShowcaseRoom()
        room.startReply(try fixture("m4"))
        room.edit(try fixture("m4"))
        XCTAssertNil(room.replyTarget)
        XCTAssertEqual(room.editingMessage?.id, "m4")
        room.startReply(try fixture("m2"))
        XCTAssertNil(room.editingMessage)
        XCTAssertEqual(room.replyTarget?.id, "m2")
    }

    // MARK: Jumping

    func testJumpingToAQuotedMessageOutsideTheWindowReplacesIt() {
        let room = ShowcaseRoom()
        room.jump(to: "m11")
        XCTAssertTrue(ids(room).contains("m11"))
        XCTAssertEqual(room.highlightedMessageId, "m11")
        XCTAssertEqual(room.scrollTarget, "m11")
        XCTAssertTrue(room.isJumped)
        XCTAssertTrue(room.hasNewerMessages)
    }

    func testJumpingToARowTheWindowAlreadyHoldsOnlyHighlightsIt() {
        let room = ShowcaseRoom()
        let before = ids(room)
        room.jump(to: "m2")
        XCTAssertEqual(ids(room), before)
        XCTAssertEqual(room.highlightedMessageId, "m2")
        XCTAssertEqual(room.scrollTarget, "m2")
        XCTAssertFalse(room.isJumped)
        XCTAssertFalse(room.hasNewerMessages)
    }

    func testJumpingToAMessageThatIsGoneLeavesTheWindowAlone() {
        let room = ShowcaseRoom()
        let before = ids(room)
        room.jump(to: SampleData.removedQuotedMessageId)
        XCTAssertEqual(ids(room), before)
        XCTAssertEqual(room.replyPreviews[SampleData.removedQuotedMessageId], .unavailable)
        XCTAssertNil(room.highlightedMessageId)
        XCTAssertFalse(room.isJumped)
    }

    func testTheViewClearsTheScrollTargetItHandled() {
        let room = ShowcaseRoom()
        room.jump(to: "m11")
        room.scrollTargetHandled()
        XCTAssertNil(room.scrollTarget)
        XCTAssertEqual(room.highlightedMessageId, "m11")
    }

    func testPagingTheNewerEdgeEndsInTheLatestWindowRatherThanFlippingInPlace() {
        let room = ShowcaseRoom()
        room.jump(to: "m11")
        room.loadNewer()
        XCTAssertTrue(room.isJumped)
        XCTAssertTrue(ids(room).contains("m11"))
        room.loadNewer()
        XCTAssertFalse(room.isJumped)
        XCTAssertFalse(room.hasNewerMessages)
        XCTAssertEqual(ids(room), ["m2", "m3", "m14", "m15", "m4"])
    }

    func testReturningToTheLatestDropsTheJumpedWindow() {
        let room = ShowcaseRoom()
        room.jump(to: "m11")
        room.scrollTargetHandled()
        room.returnToLatest()
        XCTAssertEqual(ids(room), ["m2", "m3", "m14", "m15", "m4"])
        XCTAssertFalse(room.isJumped)
        XCTAssertFalse(room.hasNewerMessages)
        XCTAssertNil(room.scrollTarget)
    }

    func testSendingWhileJumpedReturnsToTheLatestFirst() throws {
        let room = ShowcaseRoom()
        room.startReply(try fixture("m11"))
        room.jump(to: "m11")
        XCTAssertTrue(room.isJumped)
        XCTAssertTrue(room.send("Confirming the plan."))
        XCTAssertFalse(room.isJumped)
        let sent = try XCTUnwrap(room.messages.last)
        XCTAssertEqual(sent.replyToMessageId, "m11")
        XCTAssertEqual(sent.text, "Confirming the plan.")
    }
}
