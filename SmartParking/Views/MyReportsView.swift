import SwiftUI
import UIKit

@MainActor
struct MyReportsView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var coordinator: ReportSessionCoordinator
    @StateObject private var viewModel: MyReportsViewModel

    @State private var showNewReport = false
    @State private var submissionMessage: String?

    private let levels: [LevelSummary]
    private let parkingService: ParkingServicing

    // MARK: - Initialization

    init(
        userId: String,
        coordinator: ReportSessionCoordinator,
        levels: [LevelSummary],
        parkingService: ParkingServicing
    ) {
        self.coordinator = coordinator
        self.levels = levels
        self.parkingService = parkingService

        _viewModel = StateObject(
            wrappedValue: MyReportsViewModel(
                userId: userId,
                coordinator: coordinator
            )
        )
    }

    // MARK: - Main view

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    if let submissionMessage {

                        banner(
                            title: "Report update",
                            message: submissionMessage,
                            icon: "info.circle",
                            color: Palette.accent,
                            background: Palette.accentSoft
                        )
                    }

                    if viewModel.pendingCount > 0 {
                        pendingBanner
                    }

                    if viewModel.isCached,
                       let fetchedAt = viewModel.fetchedAt {

                        cachedBanner(fetchedAt)
                    }

                    if let warning = viewModel.warning {

                        banner(
                            title: "Could not refresh reports",
                            message: warning,
                            icon: "wifi.exclamationmark",
                            color: Palette.amberText,
                            background: Palette.amberSoft
                        )
                    }

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    if let error = coordinator.errorMessage {

                        errorBanner(error)

                        Button("Try again") {
                            coordinator.retrySession()
                        }
                        .font(AppFont.button)
                        .foregroundStyle(Palette.accent)
                    }

                    if coordinator.activeUserId != viewModel.userId {

                        ProgressView("Preparing report storage…")
                            .frame(maxWidth: .infinity)
                            .padding(32)

                    } else if viewModel.isLoading &&
                                !viewModel.hasLoaded {

                        ProgressView("Loading reports…")
                            .tint(Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(32)

                    } else if viewModel.isEmpty &&
                                viewModel.warning == nil &&
                                (coordinator.isConnected ||
                                 viewModel.fetchedAt != nil) {

                        emptyState

                    } else if viewModel.isEmpty {

                        Text("No reports are available on this phone.")
                            .font(AppFont.body)
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(24)

                    } else {

                        ForEach(viewModel.items) { item in
                            reportRow(item)
                        }
                    }
                }
                .padding(16)
            }
            .background(Palette.screen)
            .navigationTitle("My reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {

                    Button {

                        showNewReport = true

                    } label: {

                        Image(systemName: "plus")
                            .foregroundStyle(Palette.accent)
                    }
                    .accessibilityLabel("New report")
                    .disabled(
                        coordinator.activeUserId != viewModel.userId
                    )
                }
            }
            .refreshable {
                await viewModel.refresh(force: true)
            }
            .task(
                id: "\(coordinator.revision)|\(coordinator.isConnected)|\(coordinator.activeUserId ?? "")"
            ) {

                await viewModel.refresh()
            }
            .sheet(
                isPresented: $showNewReport,
                onDismiss: {

                    Task {
                        await viewModel.refresh()
                    }
                }
            ) {

                ReportProblemView(
                    userId: viewModel.userId,
                    coordinator: coordinator,
                    levels: levels,
                    parkingService: parkingService,
                    onComplete: { submission in

                        submissionMessage =
                            message(for: submission)
                    }
                )
            }
        }
        .onChange(of: coordinator.activeUserId) { _, userId in

            if userId != viewModel.userId {

                showNewReport = false
                dismiss()
            }
        }
    }

    // MARK: - Report row

    private func reportRow(
        _ item: ReportHistoryItem
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 12) {

                ReportPhotoThumbnail(
                    item: item,
                    viewModel: viewModel,
                    connected: coordinator.isConnected
                )

                VStack(alignment: .leading, spacing: 6) {

                    Text(item.displayCode)
                        .font(AppFont.monoId)
                        .foregroundStyle(Palette.accent)

                    Text(item.kind.title)
                        .font(AppFont.heading1)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Text(
                        viewModel.dateTitle(
                            for: item.reportedAt
                        )
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)

                    stateBadge(item.state)
                }

                Spacer(minLength: 0)
            }

            if let note = item.note,
               !note.isEmpty {

                Text(note)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            if !item.hasPhoto {

                Text("Report without a photo")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }

            if item.state == .rejected {

                Divider()

                Label(
                    "ParkWise did not accept the report of \(item.displayCode). You can send it again with Report a problem.",
                    systemImage: "exclamationmark.circle"
                )
                .font(AppFont.caption)
                .foregroundStyle(Palette.redInk)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Delivery state

    private func stateBadge(
        _ state: ReportDeliveryState
    ) -> some View {

        let color = stateColor(state)

        return Text(state.title)
            .font(AppFont.overline)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(
                    cornerRadius: Radius.badge
                )
                .fill(stateBackground(state))
            )
    }

    private func stateColor(
        _ state: ReportDeliveryState
    ) -> Color {

        switch state {

        case .sent:
            return Palette.greenInk

        case .waiting:
            return Palette.amberText

        case .sending:
            return Palette.accent

        case .rejected:
            return Palette.redInk
        }
    }

    private func stateBackground(
        _ state: ReportDeliveryState
    ) -> Color {

        switch state {

        case .sent:
            return Palette.greenSoft

        case .waiting:
            return Palette.amberSoft

        case .sending:
            return Palette.accentSoft

        case .rejected:
            return Palette.redSoft
        }
    }

    // MARK: - Pending reports banner

    private var pendingBanner: some View {

        let count = viewModel.pendingCount

        if coordinator.isConnected {

            return banner(
                title: "Sending",
                message: count == 1
                    ? "1 report is going to ParkWise, one at a time."
                    : "\(count) reports are going to ParkWise, one at a time.",
                icon: "arrow.triangle.2.circlepath",
                color: Palette.accent,
                background: Palette.accentSoft
            )

        } else {

            return banner(
                title: "No signal",
                message: count == 1
                    ? "1 report is saved on this phone and will be sent when you are back online."
                    : "\(count) reports are saved on this phone and will be sent when you are back online.",
                icon: "wifi.slash",
                color: Palette.amberText,
                background: Palette.amberSoft
            )
        }
    }

    // MARK: - Cached history banner

    private func cachedBanner(
        _ fetchedAt: Date
    ) -> some View {

        let date = fetchedAt.formatted(
            date: .abbreviated,
            time: .shortened
        )

        return banner(
            title: "Saved on this phone",
            message: "Updated \(date). It updates when you're back online.",
            icon: "internaldrive",
            color: Palette.accent,
            background: Palette.accentSoft
        )
    }

    // MARK: - Generic banner

    private func banner(
        title: String,
        message: String,
        icon: String,
        color: Color,
        background: Color
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Image(systemName: icon)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 5) {

                Text(title)
                    .font(AppFont.heading1)

                Text(message)
                    .font(AppFont.body)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: Radius.card
            )
            .fill(background)
        )
    }

    private func errorBanner(
        _ message: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            banner(
                title: "Something went wrong",
                message: message,
                icon: "exclamationmark.circle",
                color: Palette.redInk,
                background: Palette.redSoft
            )

            Button("Try again") {

                Task {
                    await viewModel.refresh(force: true)
                }
            }
            .font(AppFont.button)
            .foregroundStyle(Palette.accent)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {

        VStack(spacing: 12) {

            Image(systemName: "doc.text")
                .font(.system(size: 30))
                .foregroundStyle(Palette.accent)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Palette.accentSoft)
                )

            Text("No reports yet")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)

            Text(
                "When a spot does not match the app, report it here. It helps ParkWise show the real state of the lot."
            )
            .font(AppFont.body)
            .foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)

            Button {

                showNewReport = true

            } label: {

                Label(
                    "New report",
                    systemImage: "plus"
                )
                .font(AppFont.button)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(
                        cornerRadius: Radius.card
                    )
                    .fill(Palette.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Submission feedback

    private func message(
        for submission: ReportSubmission
    ) -> String {

        let code = submission.report.displayCode

        switch submission.state {

        case .sent:

            return "Report of \(code) sent. Thank you."

        case .waiting, .sending:

            return "Report of \(code) saved on this phone. It will be sent when you are back online."

        case .rejected:

            return "ParkWise did not accept the report of \(code). You can send it again with Report a problem."
        }
    }
}

// MARK: - Report photo thumbnail

@MainActor
private struct ReportPhotoThumbnail: View {

    let item: ReportHistoryItem
    let viewModel: MyReportsViewModel
    let connected: Bool

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: Radius.small
            )
            .fill(Palette.screen)

            if let image {

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            } else if isLoading {

                ProgressView()
                    .tint(Palette.accent)

            } else {

                Image(
                    systemName: item.hasPhoto
                        ? "photo"
                        : "doc.text"
                )
                .font(.system(size: 24))
                .foregroundStyle(Palette.muted)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Radius.small
            )
        )
        .accessibilityLabel(
            item.hasPhoto
                ? "Report photo"
                : "Report without a photo"
        )
        .task(
            id: "\(item.photoTaskId)|\(connected)"
        ) {

            await loadPhoto()
        }
    }

    private func loadPhoto() async {

        guard item.hasPhoto else {

            image = nil
            return
        }

        guard image == nil else {
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {

            let data = try await viewModel.photoData(
                for: item
            )

            try Task.checkCancellation()

            if let data {
                image = UIImage(data: data)
            }

        } catch {

            // Keep the placeholder if the photo
            // is not currently available.
        }
    }
}