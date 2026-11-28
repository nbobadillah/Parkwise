import SwiftUI
import UIKit
import AVFoundation

@MainActor
struct ReportProblemView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var coordinator: ReportSessionCoordinator
    @StateObject private var viewModel: ReportFormViewModel

    @State private var showSpotPicker = false
    @State private var showCamera = false

    private let levels: [LevelSummary]
    private let parkingService: ParkingServicing
    private let onComplete: (ReportSubmission) -> Void

    // MARK: - Initialization

    init(
        userId: String,
        coordinator: ReportSessionCoordinator,
        levels: [LevelSummary],
        parkingService: ParkingServicing,
        preselectedSpot: ReportSpot? = nil,
        onComplete: @escaping (ReportSubmission) -> Void
    ) {

        self.coordinator = coordinator
        self.levels = levels
        self.parkingService = parkingService
        self.onComplete = onComplete

        _viewModel = StateObject(
            wrappedValue: ReportFormViewModel(
                userId: userId,
                coordinator: coordinator,
                preselectedSpot: preselectedSpot
            )
        )
    }

    // MARK: - Main view

    var body: some View {

        NavigationStack {

            GeometryReader { geometry in

                ScrollView {

                    VStack(spacing: 16) {

                        if geometry.size.width > geometry.size.height &&
                            geometry.size.width >= 600 {

                            HStack(alignment: .top, spacing: 16) {

                                VStack(spacing: 16) {
                                    spotSection
                                    kindSection
                                }
                                .frame(maxWidth: .infinity)

                                VStack(spacing: 16) {
                                    photoSection
                                    noteSection
                                }
                                .frame(maxWidth: .infinity)
                            }

                        } else {

                            VStack(spacing: 16) {
                                spotSection
                                kindSection
                                photoSection
                                noteSection
                            }
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

                        submitSection
                    }
                    .padding(16)
                }
            }
            .background(Palette.screen)
            .navigationTitle("Report a problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") {
                        viewModel.cancelCompression()
                        dismiss()
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showSpotPicker) {

                ReportSpotPickerView(
                    levels: levels,
                    service: parkingService,
                    onSelect: { spot in

                        viewModel.selectSpot(spot)
                        showSpotPicker = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showCamera) {

                ReportCameraView(
                    onCapture: { image in

                        showCamera = false
                        viewModel.capturePhoto(image)
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .onChange(of: coordinator.activeUserId) { _, userId in

            if userId != viewModel.userId {

                viewModel.cancelCompression()
                showCamera = false
                showSpotPicker = false
                dismiss()
            }
        }
    }

    // MARK: - Spot section

    private var spotSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            SectionLabel(text: "Spot")

            if let spot = viewModel.spot {

                Text(spot.displayCode)
                    .font(AppFont.display)
                    .foregroundStyle(Palette.ink)

                Text(spot.description)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)

            } else {

                Text("No spot selected")
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)

                Text("Choose the parking spot you want to report.")
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)
            }

            Button {

                showSpotPicker = true

            } label: {

                HStack {

                    Image(systemName: "mappin.circle")

                    Text(
                        viewModel.spot == nil
                            ? "Choose"
                            : "Change"
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                }
                .font(AppFont.button)
                .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSubmitting)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Report kind section

    private var kindSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("What is wrong?")
                .font(AppFont.heading1)
                .foregroundStyle(Palette.ink)

            ForEach(ReportKind.allCases) { kind in

                Button {

                    viewModel.selectKind(kind)

                } label: {

                    HStack(spacing: 12) {

                        Image(systemName: kind.icon)
                            .frame(width: 24)

                        Text(kind.title)
                            .font(AppFont.body)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(
                            systemName: viewModel.kind == kind
                                ? "largecircle.fill.circle"
                                : "circle"
                        )
                    }
                    .foregroundStyle(
                        viewModel.kind == kind
                            ? Palette.accent
                            : Palette.ink
                    )
                    .padding(12)
                    .background(
                        RoundedRectangle(
                            cornerRadius: Radius.small
                        )
                        .fill(
                            viewModel.kind == kind
                                ? Palette.accentSoft
                                : Palette.screen
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Photo section

    private var photoSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Photo")
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text("Optional")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }

            if viewModel.isCompressing {

                HStack(spacing: 12) {

                    ProgressView()
                        .tint(Palette.accent)

                    Text("Making the photo smaller on the phone…")
                        .font(AppFont.body)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.vertical, 12)

                Button("Cancel") {
                    viewModel.cancelCompression()
                }
                .font(AppFont.button)
                .foregroundStyle(Palette.accent)

            } else if let photo = viewModel.photo {

                if let image = UIImage(data: photo.data) {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: Radius.small
                            )
                        )
                }

                Label(
                    "Photo ready",
                    systemImage: "checkmark.circle.fill"
                )
                .font(AppFont.heading2)
                .foregroundStyle(Palette.greenInk)

                Text(
                    "\(Int(photo.originalKB)) KB → \(Int(photo.compressedKB)) KB"
                )
                .font(AppFont.monoData)
                .foregroundStyle(Palette.ink)

                Text("Resized on the phone before sending")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)

                Button {

                    requestCamera()

                } label: {

                    Label(
                        "Take another photo",
                        systemImage: "camera"
                    )
                }
                .font(AppFont.button)
                .foregroundStyle(Palette.accent)

                Button(role: .destructive) {

                    viewModel.removePhoto()

                } label: {

                    Label(
                        "Remove the photo",
                        systemImage: "trash"
                    )
                }
                .font(AppFont.button)

            } else {

                Button {

                    requestCamera()

                } label: {

                    Label(
                        "Take a photo",
                        systemImage: "camera"
                    )
                    .font(AppFont.button)
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(
                            cornerRadius: Radius.small
                        )
                        .fill(Palette.accentSoft)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .cardStyle()
        .disabled(viewModel.isSubmitting)
    }

    // MARK: - Note section

    private var noteSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Note")
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text("Optional")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }

            ZStack(alignment: .topLeading) {

                if viewModel.note.isEmpty {

                    Text(
                        "A car without a reservation since 8:10"
                    )
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
                }

                TextEditor(
                    text: Binding(
                        get: { viewModel.note },
                        set: { viewModel.updateNote($0) }
                    )
                )
                .font(AppFont.body)
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .disabled(viewModel.isSubmitting)
            }
            .padding(8)
            .background(Palette.screen)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Radius.small
                )
            )

            HStack {

                Spacer()

                Text(
                    "\(viewModel.noteCount)/\(ReportFormViewModel.maxNoteLength)"
                )
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Submit section

    private var submitSection: some View {

        VStack(spacing: 12) {

            Button {

                Task {

                    if let submission = await viewModel.submit() {

                        onComplete(submission)
                        dismiss()
                    }
                }

            } label: {

                HStack(spacing: 8) {

                    if viewModel.isSubmitting {

                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        viewModel.isSubmitting
                            ? "Sending report…"
                            : "Send report"
                    )
                    .font(AppFont.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    RoundedRectangle(
                        cornerRadius: Radius.card
                    )
                    .fill(
                        viewModel.canSubmit
                            ? Palette.accent
                            : Palette.muted
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)

            if !coordinator.isConnected {

                Label(
                    "Without signal it is saved and sent when you are back online.",
                    systemImage: "wifi.slash"
                )
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            }

            if coordinator.activeUserId != viewModel.userId {

                Text("Preparing report storage…")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    // MARK: - Error banner

    private func errorBanner(
        _ message: String
    ) -> some View {

        HStack(alignment: .top, spacing: 8) {

            Image(systemName: "exclamationmark.circle")

            Text(message)
                .font(AppFont.body)

            Spacer()
        }
        .foregroundStyle(Palette.redInk)
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: Radius.small
            )
            .fill(Palette.redSoft)
        )
    }

    // MARK: - Camera permission

    private func requestCamera() {

        guard ReportCameraView.isAvailable else {

            viewModel.errorMessage =
                "The camera is not available on this device."

            return
        }

        viewModel.errorMessage = nil

        switch AVCaptureDevice.authorizationStatus(
            for: .video
        ) {

        case .authorized:

            showCamera = true

        case .notDetermined:

            Task {

                let granted = await AVCaptureDevice.requestAccess(
                    for: .video
                )

                guard coordinator.activeUserId ==
                        viewModel.userId else {
                    return
                }

                if granted {

                    showCamera = true

                } else {

                    viewModel.errorMessage =
                        "Camera access was denied. You can enable it in Settings."
                }
            }

        case .denied, .restricted:

            viewModel.errorMessage =
                "Camera access is unavailable. Check your Settings."

        @unknown default:

            viewModel.errorMessage =
                "Could not access the camera."
        }
    }
}