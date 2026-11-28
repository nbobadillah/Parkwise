import Foundation

struct ReportDraft: Codable {
    var spot: ReportSpot?
    var kind: ReportKind
    var note: String
}

@MainActor
final class ReportDraftStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Form draft

    func save(
        _ draft: ReportDraft,
        userId: String
    ) {
        guard let data = try? JSONEncoder().encode(draft) else {
            return
        }

        defaults.set(
            data,
            forKey: draftKey(userId)
        )
    }

    func load(userId: String) -> ReportDraft? {

        guard let data = defaults.data(
            forKey: draftKey(userId)
        ) else {
            return nil
        }

        return try? JSONDecoder().decode(
            ReportDraft.self,
            from: data
        )
    }

    func clearDraft(userId: String) {
        defaults.removeObject(
            forKey: draftKey(userId)
        )
    }

    // MARK: - Last used report kind

    func saveLastKind(
        _ kind: ReportKind,
        userId: String
    ) {
        defaults.set(
            kind.rawValue,
            forKey: lastKindKey(userId)
        )
    }

    func lastKind(userId: String) -> ReportKind {

        guard let value = defaults.string(
            forKey: lastKindKey(userId)
        ),
        let kind = ReportKind(rawValue: value) else {
            return .occupied
        }

        return kind
    }

    // MARK: - Session cleanup

    func clear(userId: String) {
        clearDraft(userId: userId)

        defaults.removeObject(
            forKey: lastKindKey(userId)
        )
    }

    // MARK: - User-scoped keys

    private func draftKey(_ userId: String) -> String {
        "report.draft.\(userId)"
    }

    private func lastKindKey(_ userId: String) -> String {
        "report.lastKind.\(userId)"
    }
}