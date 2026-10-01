import SwiftUI

struct FindSpotView: View {
    let onReserve: (SpotListing) -> Void

    @State private var query = ""
    @State private var filter = FindSpotData.filters[0]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(FindSpotData.spots.count) spots found")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.subtle)

                    VStack(spacing: 10) {
                        ForEach(FindSpotData.spots) { spot in
                            SpotResultRow(spot: spot) {
                                onReserve(spot)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find a spot")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    searchField
                    micButton
                }

                HStack(spacing: 8) {
                    ForEach(FindSpotData.filters, id: \.self) { item in
                        FilterChip(title: item, isSelected: filter == item) {
                            filter = item
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
            TextField(
                "Search",
                text: $query,
                prompt: Text("Spot code, zone, level…").foregroundColor(Palette.muted)
            )
            .font(.system(size: 14))
            .foregroundStyle(Palette.ink)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.neutral)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.border, lineWidth: 1.5)
        )
    }

    private var micButton: some View {
        Button {} label: {
            Image(systemName: "mic")
                .font(.system(size: 17))
                .foregroundStyle(Palette.accent)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.accent.opacity(0.55), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}