import SwiftUI

struct AccessibleEVSpotsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    availabilityContent
                }
                .padding(18)
            }
            .background(Palette.screen)
            .navigationTitle("Accessible and EV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Palette.accent)
                }
            }
            .task {
                if viewModel.specialSpotsAvailability == nil {
                    await viewModel.loadSpecialSpotsAvailability()
                }
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Special parking availability")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.ink)

            Text("Check accessible parking spaces and electric vehicle spaces available on each level.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)

            Text("Availability reflects the latest reported status. It is not a reservation.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private var availabilityContent: some View {
        if viewModel.isLoadingSpecialSpots &&
            viewModel.specialSpotsAvailability == nil {
            ProgressView("Loading availability...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

        } else if let availability = viewModel.specialSpotsAvailability {
            cacheInformation

            ForEach(availability.levels) { level in
                levelCard(level)
            }

            if let error = viewModel.specialSpotsErrorMessage {
                Text("Could not refresh data: \(error)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }

            refreshButton

        } else if let error = viewModel.specialSpotsErrorMessage {
            ContentUnavailableView {
                Label("Availability unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try again") {
                    Task {
                        await viewModel.loadSpecialSpotsAvailability()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        } else {
            ProgressView("Loading availability...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    private var cacheInformation: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.specialSpotsFromCache
                  ? "internaldrive"
                  : "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.specialSpotsFromCache
                     ? "Saved data"
                     : "Updated from server")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                if let date = viewModel.specialSpotsFetchedAt {
                    Text("Updated \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }

            Spacer()

            if viewModel.specialSpotsFromCache {
                Text("OFFLINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(13)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func levelCard(_ level: SpecialSpotLevelAvailability) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(level.levelName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 12) {
                categoryCard(
                    title: "Accessible",
                    icon: "figure.roll",
                    counts: level.accessible
                )

                categoryCard(
                    title: "EV",
                    icon: "bolt.car",
                    counts: level.ev
                )
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func categoryCard(
        title: String,
        icon: String,
        counts: SpecialSpotCounts
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(counts.free)")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Palette.accent)

                Text("/ \(counts.total) free")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
            }

            Divider()

            countRow("Reserved", value: counts.reserved)
            countRow("Occupied", value: counts.occupied)
            countRow("Disabled", value: counts.disabled)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.screen)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func countRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.muted)

            Spacer()

            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.ink)
        }
        .font(.system(size: 11))
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.loadSpecialSpotsAvailability()
            }
        } label: {
            HStack {
                if viewModel.isLoadingSpecialSpots {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                }

                Text("Refresh availability")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isLoadingSpecialSpots)
    }
}
