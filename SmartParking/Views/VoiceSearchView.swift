import SwiftUI

struct VoiceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var viewModel: VoiceSearchViewModel

    private let onFinish: (VoiceSearchViewModel.Outcome) -> Void

    init(
        destinationID: String?,
        openReservationLevel: String?,
        service: ParkingServicing,
        networkMonitor: NetworkMonitor,
        onFinish: @escaping (VoiceSearchViewModel.Outcome) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: VoiceSearchViewModel(
                destinationID: destinationID,
                openReservationLevel: openReservationLevel,
                service: service,
                networkMonitor: networkMonitor
            )
        )
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !viewModel.isConnected {
                            NoticeBox(
                                message: viewModel.recognizesWithoutInternet
                                    ? "This iPhone recognizes your voice without internet."
                                    : "Some phones need internet to recognize voice. If it does not work, type your search instead.",
                                title: "No signal",
                                icon: "wifi.slash"
                            )
                        }

                        VoiceMicrophone(
                            viewModel: viewModel,
                            compact: verticalSizeClass == .compact || proxy.size.height < 560
                        )
                        .frame(maxWidth: .infinity)

                        if let destination = viewModel.destination {
                            VoiceDestinationCard(building: destination)
                        }

                        VoiceTryCard(phrases: viewModel.tryPhrases)

                        if !viewModel.recent.isEmpty {
                            VoiceRecentList(searches: viewModel.recent) { search in
                                Task {
                                    await viewModel.repeatSearch(search)
                                }
                            }
                        }

                        Button {
                            viewModel.typeInstead()
                        } label: {
                            Label("Type instead", systemImage: "keyboard")
                                .font(AppFont.button)
                                .foregroundStyle(Palette.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                        .stroke(Palette.accent, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Palette.card)
        .task {
            await viewModel.open()
        }
        .onDisappear {
            viewModel.close()
        }
        .onChange(of: viewModel.outcome) { _, outcome in
            guard let outcome else { return }
            onFinish(outcome)
            dismiss()
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.close()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close voice search")

            Text("Voice search")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            ForEach(VoiceLanguage.allCases) { option in
                ChoiceChip(
                    title: option.shortName,
                    isSelected: option == viewModel.language
                ) {
                    viewModel.choose(option)
                }
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }
}
