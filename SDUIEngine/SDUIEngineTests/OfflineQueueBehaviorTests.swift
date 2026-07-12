import XCTest
@testable import SDUIEngine

/// Тесты для проверки поведения оффлайн-очереди синхронизации
/// Проверяет механизмы повторных попыток, backoff и обработку ошибок
final class OfflineQueueBehaviorTests: XCTestCase {

    /// Тест проверяет, что при ошибке сервера (503) операция помечается как failed
    /// и механизм backoff блокирует немедленную повторную попытку
    func testFlushQueueMarksFailedAndBackoffPreventsImmediateRetry() async {
        // Создаем заглушку удаленного сервера, которая всегда возвращает ошибку 503
        let remote = RemoteStub(plan: [
            .init(result: .failure(RemoteRequestError.badStatusCode(503)))
        ])
        let dataLayer = OfflineDataLayer(remote: remote)
        await clearQueue(dataLayer)

        // Отправляем POST запрос, который должен быть добавлен в очередь
        _ = try? await dataLayer.request(endpoint: "https://example.com/invoices", method: .post, body: ["id": .string("1")])

        // Ждем, пока будет выполнен удаленный вызов
        await waitForRemoteCalls(remote, expectedAtLeast: 1)

        // Ждем, пока операция в очереди будет помечена как failed с 1 попыткой
        await waitForQueueState(dataLayer, timeoutSeconds: 1.0) { ops in
            ops.count == 1 && ops[0].status == .failed && ops[0].attempt == 1
        }

        // Проверяем состояние очереди после первой попытки flush
        let afterFirstFlush = await dataLayer.syncQueue.all()
        XCTAssertEqual(afterFirstFlush.count, 1)
        XCTAssertEqual(afterFirstFlush[0].status, .failed)
        XCTAssertEqual(afterFirstFlush[0].attempt, 1)

        // Вызываем flushQueue снова - из-за механизма backoff повторный вызов не должен произойти
        await dataLayer.flushQueue()
        let callsAfterSecondFlush = await remote.callCount
        XCTAssertEqual(callsAfterSecondFlush, 1, "Immediate retry should be blocked by backoff")
    }

    /// Тест проверяет, что после истечения времени backoff выполняется повторная попытка
    /// и при успехе операция удаляется из очереди
    func testFlushQueueRetriesAfterBackoffWindowAndRemovesOperationOnSuccess() async {
        // Создаем заглушку, которая сначала возвращает ошибку, затем успех
        let remote = RemoteStub(plan: [
            .init(result: .failure(RemoteRequestError.badStatusCode(503))),
            .init(result: .success(.object(["ok": .bool(true)])))
        ])
        let dataLayer = OfflineDataLayer(remote: remote)
        await clearQueue(dataLayer)

        // Отправляем POST запрос
        _ = try? await dataLayer.request(endpoint: "https://example.com/invoices", method: .post, body: ["id": .string("2")])

        // Ждем выполнения первого запроса и пометки операции как failed
        await waitForRemoteCalls(remote, expectedAtLeast: 1)
        await waitForQueueState(dataLayer, timeoutSeconds: 1.0) { ops in
            ops.count == 1 && ops[0].status == .failed && ops[0].attempt == 1
        }

        var ops = await dataLayer.syncQueue.all()
        XCTAssertEqual(ops.count, 1)

        // Искусственно устанавливаем старую дату обновления операции,
        // чтобы backoff истек и можно было выполнить повторную попытку
        var op = ops[0]
        op.status = .failed
        op.updatedAt = "2000-01-01T00:00:00Z"  // Очень старая дата
        await dataLayer.syncQueue.update(op)

        // Вызываем flushQueue - должна выполниться повторная попытка
        await dataLayer.flushQueue()

        // Проверяем, что очередь пуста (операция удалена после успеха)
        ops = await dataLayer.syncQueue.all()
        XCTAssertTrue(ops.isEmpty)

        // Проверяем, что было сделано 2 вызова (первая ошибка + успешный retry)
        let calls = await remote.callCount
        XCTAssertEqual(calls, 2)
    }

    /// Ожидает указанного количества удаленных вызовов
    /// Используется для синхронизации тестов с асинхронными операциями
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

    /// Ожидает, пока очередь не будет в заданном состоянии
    /// Используется для проверки состояния операций в очереди
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

    /// Очищает очередь перед тестом
    /// Удаляет все операции из syncQueue
    private func clearQueue(_ dataLayer: OfflineDataLayer) async {
        let existing = await dataLayer.syncQueue.all()
        for op in existing {
            await dataLayer.syncQueue.remove(opID: op.opID)
        }
    }
}
