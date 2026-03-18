import XCTest
@testable import SDUIEngine

final class OfflineQueueBehaviorTests: XCTestCase {
    func testFlushQueueMarksFailedAndBackoffPreventsImmediateRetry() async {
        let remote = RemoteStub(plan: [
            .init(result: .failure(RemoteRequestError.badStatusCode(503)))
        ])
        let dataLayer = OfflineDataLayer(remote: remote)
        await clearQueue(dataLayer)

        _ = try? await dataLayer.request(endpoint: "https://example.com/invoices", method: .post, body: ["id": .string("1")])
        await waitForRemoteCalls(remote, expectedAtLeast: 1)
        await waitForQueueState(dataLayer, timeoutSeconds: 1.0) { ops in
            ops.count == 1 && ops[0].status == .failed && ops[0].attempt == 1
        }

        let afterFirstFlush = await dataLayer.syncQueue.all()
        XCTAssertEqual(afterFirstFlush.count, 1)
        XCTAssertEqual(afterFirstFlush[0].status, .failed)
        XCTAssertEqual(afterFirstFlush[0].attempt, 1)

        await dataLayer.flushQueue()
        let callsAfterSecondFlush = await remote.callCount
        XCTAssertEqual(callsAfterSecondFlush, 1, "Immediate retry should be blocked by backoff")
    }

    func testFlushQueueRetriesAfterBackoffWindowAndRemovesOperationOnSuccess() async {
        let remote = RemoteStub(plan: [
            .init(result: .failure(RemoteRequestError.badStatusCode(503))),
            .init(result: .success(.object(["ok": .bool(true)])))
        ])
        let dataLayer = OfflineDataLayer(remote: remote)
        await clearQueue(dataLayer)

        _ = try? await dataLayer.request(endpoint: "https://example.com/invoices", method: .post, body: ["id": .string("2")])
        await waitForRemoteCalls(remote, expectedAtLeast: 1)
        await waitForQueueState(dataLayer, timeoutSeconds: 1.0) { ops in
            ops.count == 1 && ops[0].status == .failed && ops[0].attempt == 1
        }

        var ops = await dataLayer.syncQueue.all()
        XCTAssertEqual(ops.count, 1)

        var op = ops[0]
        op.status = .failed
        op.updatedAt = "2000-01-01T00:00:00Z"
        await dataLayer.syncQueue.update(op)

        await dataLayer.flushQueue()

        ops = await dataLayer.syncQueue.all()
        XCTAssertTrue(ops.isEmpty)
        let calls = await remote.callCount
        XCTAssertEqual(calls, 2)
    }

    private func waitForRemoteCalls(
        _ remote: RemoteStub,
        expectedAtLeast expected: Int,
        timeoutSeconds: TimeInterval = 1.5
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await remote.callCount >= expected {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func waitForQueueState(
        _ dataLayer: OfflineDataLayer,
        timeoutSeconds: TimeInterval = 1.5,
        predicate: @escaping ([PendingOperation]) -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let ops = await dataLayer.syncQueue.all()
            if predicate(ops) {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func clearQueue(_ dataLayer: OfflineDataLayer) async {
        let existing = await dataLayer.syncQueue.all()
        for op in existing {
            await dataLayer.syncQueue.remove(opID: op.opID)
        }
    }
}
