import SwiftUI

struct FindCarView: View {
    @ObservedObject var viewModel: ReservationViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoadingVehicle {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let vehicle = viewModel.vehicle {
                        if let errorMessage = viewModel.vehicleErrorMessage {
                            AuthBanner(message: errorMessage, isError: true)
                        }
                        summary(vehicle)
                    } else if let errorMessage = viewModel.vehicleErrorMessage {
                        AuthBanner(message: errorMessage, isError: true)
                    } else {
                        PlaceholderView(
                            title: "No parked car",
                            message: "A checked-in reservation will appear here.",
                            icon: "car"
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.screen)
        .task { await viewModel.loadVehicle() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find my car")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Vehicle location")
                .font(.system(size: 13))
                .foregroundStyle(Palette.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 17)
        .background(Palette.card, ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private func summary(_ vehicle: ParkedVehicle) -> some View {
        HStack(spacing: 12) {
            SummaryTile(
                label: "Spot",
                value: vehicle.spotCode,
                caption: "\(vehicle.levelCode) · Zone \(vehicle.zone)",
                valueColor: Palette.accent,
                monospaced: true
            )
            SummaryTile(
                label: "Parked",
                value: vehicle.parkedAt.formatted(date: .omitted, time: .shortened),
                caption: vehicle.parkedAt.formatted(date: .abbreviated, time: .omitted),
                valueColor: Palette.ink
            )
        }
    }
}