import BackgroundTasks
import Foundation

/// Owns one short system-scheduled refresh. iOS chooses the exact run time based
/// on battery, usage, and network conditions; apps cannot demand a clock time.
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    static let identifier = "in.sachinserver.News-App.refresh"

    private init() {}

    /// Registration happens during app launch, before a background task arrives.
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.identifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handle(refreshTask)
        }
    }

    /// Politely asks iOS for an opportunity no earlier than 30 minutes later.
    func schedule() {
        // Keep at most one future request with this identifier. Without this small
        // cleanup, repeatedly backgrounding the app could fill the system queue.
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.error("Could not schedule background refresh: \(error)")
        }
    }

    /// Downloads page one; the repository also writes it to Core Data.
    private func handle(_ backgroundTask: BGAppRefreshTask) {
        schedule()
        let repository = DefaultNewsRepository()
        let work = Task {
            do {
                _ = try await repository.fetchHeadlines(page: 1, pageSize: 20)
                backgroundTask.setTaskCompleted(success: true)
            } catch {
                backgroundTask.setTaskCompleted(success: false)
            }
        }

        /// Cancellation reaches URLSession if the system ends our time budget.
        backgroundTask.expirationHandler = { work.cancel() }
    }
}
