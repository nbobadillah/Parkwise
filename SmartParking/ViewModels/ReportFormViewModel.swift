import Foundation
import Combine
import UIKit

@MainActor
final class ReportFormViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var spot: ReportSpot?
    @Published private(set) var kind: ReportKind
    @Published private(set) var note: String

    @Published private(set) var photo: CompressedReportPhoto?

    @Published private(set) var isCompressing = false
    @Published private(set) var isSubmitting = false

    @Published var errorMessage: String?

    // MARK: - Dependencies

    let userId: String

    private let coordinator: ReportSessionCoordinator

    private var compressionTask: Task<Void, Never>?
    private var compressionId = UUID()

    static let maxNoteLength = 280

    // MARK: - Initialization

    init(
        userId: String,
        coordinator: ReportSessionCoordinator,
        preselectedSpot: ReportSpot? = nil
    ) {

        self.userId = userId
        self.coordinator = coordinator

        let draft = coordinator.draftStore.load(
            userId: userId
        )

        spot = preselectedSpot ?? draft?.spot

        kind = draft?.kind ??
            coordinator.draftStore.lastKind(
                userId: userId
            )

        note = Self.limitedNote(draft?.note ?? "")

        persistDraft()
    }

    // MARK: - Form validation

    var canSubmit: Bool {

        spot != nil &&
        !isCompressing &&
        !isSubmitting &&
        coordinator.activeUserId == userId &&
        note.utf16.count <= Self.maxNoteLength
    }

    var noteCount: Int {
        note.utf16.count
    }

    var hasPhoto: Bool {
        photo != nil
    }

    // MARK: - Form updates

    func selectSpot(_ spot: ReportSpot) {

        guard !isSubmitting else { return }

        self.spot = spot

        persistDraft()
    }

    func selectKind(_ kind: ReportKind) {

        guard !isSubmitting else { return }

        self.kind = kind

        persistDraft()
    }

    func updateNote(_ value: String) {

        guard !isSubmitting else { return }

        note = Self.limitedNote(value)

        persistDraft()
    }

    private static func limitedNote(
        _ value: String
    ) -> String {

        var result = ""
        var length = 0

        for character in value {

            let size = String(character).utf16.count

            guard length + size <= maxNoteLength else {
                break
            }

            result.append(character)
            length += size
        }

        return result
    }

    // MARK: - Photo capture

    func capturePhoto(_ image: UIImage) {

        guard !isSubmitting else { return }

        cancelCompression()

        photo = nil
        errorMessage = nil
        isCompressing = true

        let currentId = UUID()
        compressionId = currentId

        compressionTask = Task { [weak self] in

            do {

                // Convert the captured image outside
                // the main actor.
                let worker = Task.detached(
                    priority: .userInitiated
                ) {
                    try Task.checkCancellation()

                    guard let data = image.jpegData(
                        compressionQuality: 1.0
                    ) else {
                        throw ReportPhotoError.invalidImage
                    }

                    return data
                }

                let originalData =
                    try await withTaskCancellationHandler(
                        operation: {
                            try await worker.value
                        },
                        onCancel: {
                            worker.cancel()
                        }
                    )

                try Task.checkCancellation()

                let compressed =
                    try await ReportPhotoCompressor.compress(
                        originalData
                    )

                try Task.checkCancellation()

                guard let self,
                      self.compressionId == currentId else {
                    return
                }

                self.photo = compressed
                self.isCompressing = false
                self.compressionTask = nil

            } catch {

                guard let self,
                      self.compressionId == currentId else {
                    return
                }

                self.isCompressing = false
                self.compressionTask = nil

                if !Task.isCancelled {
                    self.errorMessage =
                        error.localizedDescription
                }
            }
        }
    }

    func removePhoto() {

        guard !isSubmitting else { return }

        cancelCompression()

        photo = nil
        errorMessage = nil
    }

    func cancelCompression() {

        compressionId = UUID()

        compressionTask?.cancel()
        compressionTask = nil

        isCompressing = false
    }

    // MARK: - Submit report

    func submit() async -> ReportSubmission? {

        guard canSubmit,
              let spot else {
            return nil
        }

        isSubmitting = true
        errorMessage = nil

        defer {
            isSubmitting = false
        }

        do {

            let submission = try await coordinator.submit(
                userId: userId,
                spot: spot,
                kind: kind,
                note: note,
                photo: photo?.data
            )

            coordinator.draftStore.saveLastKind(
                kind,
                userId: userId
            )

            coordinator.draftStore.clearDraft(
                userId: userId
            )

            return submission

        } catch {

            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }

            return nil
        }
    }

    // MARK: - Draft persistence

    private func persistDraft() {

        guard coordinator.activeUserId == userId else {
            return
        }

        let draft = ReportDraft(
            spot: spot,
            kind: kind,
            note: note
        )

        coordinator.draftStore.save(
            draft,
            userId: userId
        )
    }
}