import Foundation

enum OdinPendingAction {
    case calendarClarification(originalCommand: String, createdAt: Date)
    case calendarCreateConfirmation(title: String, startDate: Date, duration: TimeInterval, createdAt: Date)
    case trelloClarification(originalCommand: String, createdAt: Date)
}

protocol OdinPendingActionManaging {
    func set(_ action: OdinPendingAction)
    func clear()
    func current() -> OdinPendingAction?
}

final class OdinPendingActionService {

    private let timeout: TimeInterval = 5 * 60
    private var action: OdinPendingAction?

    func set(_ action: OdinPendingAction) {
        self.action = action
    }

    func clear() {
        action = nil
    }

    func current() -> OdinPendingAction? {
        guard let action else {
            return nil
        }

        guard !isExpired(action) else {
            self.action = nil
            return nil
        }

        return action
    }

    private func isExpired(_ action: OdinPendingAction) -> Bool {
        let createdAt: Date

        switch action {
        case .calendarClarification(_, let date),
             .calendarCreateConfirmation(_, _, _, let date),
             .trelloClarification(_, let date):
            createdAt = date
        }

        return Date().timeIntervalSince(createdAt) > timeout
    }
}

extension OdinPendingActionService: OdinPendingActionManaging {}
