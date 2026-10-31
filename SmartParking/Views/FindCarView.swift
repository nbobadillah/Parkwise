import CoreLocation
import SwiftUI

struct FindCarView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @ObservedObject var locationService: LocationService
    @ObservedObject private var networkMonitor: NetworkMonitor
    let destinationID: String?
    let onOpenReserve: () -> Void
    @StateObject private var parkingViewModel: ParkingMapViewModel
    @State private var isLoadingSpots = false

    init(
        viewModel: ReservationViewModel,
        parkingService: ParkingServicing,
        locationService: LocationService,
        destinationID: String?,
        networkMonitor: NetworkMonitor,
        onOpenReserve: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onOpenReserve = onOpenReserve
        self.locationService = locationService
        self.destinationID = destinationID
        _networkMonitor = ObservedObject(wrappedValue: networkMonitor)
        _parkingViewModel = StateObject(
            wrappedValue: ParkingMapViewModel(service: parkingService, destination: destinationID)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !networkMonitor.isConnected && (viewModel.vehicle != nil || viewModel.parkedCar != nil) {
                        NoticeBox(message: "No connection. Showing where you saved your car.", icon: "wifi.slash")
                    }
                    if viewModel.isLoadingVehicle && viewModel.vehicle == nil && viewModel.parkedCar == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let vehicle = viewModel.vehicle {
                        if let errorMessage = viewModel.vehicleErrorMessage {
                            AuthBanner(message: errorMessage, isError: true)
                        }
                        summary(
                            spotCode: vehicle.spotCode,
                            levelTitle: "\(vehicle.levelCode) · Zone \(vehicle.zone)",
                            parkedCar: matchingParkedCar(for: vehicle)
                        )
                        floorCard(vehicle)
                        steps(levelCode: vehicle.levelCode, zone: vehicle.zone, spotCode: vehicle.spotCode)
                    } else if let parkedCar = viewModel.parkedCar {
                        if let errorMessage = viewModel.vehicleErrorMessage {
                            AuthBanner(message: errorMessage, isError: true)
                        }
                        summary(
                            spotCode: parkedCar.spotCode ?? "—",
                            levelTitle: localLevelTitle(for: parkedCar),
                            parkedCar: parkedCar
                        )
                        floorCard(parkedCar)
                        steps(
                            levelCode: parkedCar.levelCode ?? "",
                            zone: localSpot(for: parkedCar)?.zone,
                            spotCode: parkedCar.spotCode ?? "—"
                        )
                    } else {
                        if let errorMessage = viewModel.vehicleErrorMessage {
                            NoticeBox(message: errorMessage, tone: .danger, icon: "exclamationmark.circle")
                        }
                        noCarCard
                    }
                }
                .padding(16)
            }
        }
        .background(Palette.screen)
        .task(id: networkMonitor.isConnected) {
            await viewModel.loadVehicle()
        }
        .task(id: (vehicleLevelCode ?? "") + (destinationID ?? "")) {
            guard let vehicleLevelCode else { return }
            parkingViewModel.destination = destinationID
            isLoadingSpots = true
            defer { isLoadingSpots = false }
            await parkingViewModel.refresh(levelCode: vehicleLevelCode)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Find my car")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
            Text(parkedAtText)
                .font(AppFont.body)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Palette.card, ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var noCarCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No car parked")
                .font(AppFont.heading1)
                .foregroundStyle(Palette.ink)
            Text("Tap \"I parked\" on your reservation and we will remember the spot.")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            SecondaryButton(title: "Open reservation", action: onOpenReserve)
                .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var vehicleLevelCode: String? {
        viewModel.vehicle?.levelCode ?? viewModel.parkedCar?.levelCode
    }

    private func summary(spotCode: String, levelTitle: String, parkedCar: ParkedCar?) -> some View {
        HStack(spacing: 8) {
            SummaryTile(
                label: "Spot",
                value: spotCode,
                caption: levelTitle,
                valueColor: Palette.accent,
                monospaced: true
            )
            SummaryTile(
                label: "Walk",
                value: walkingMinutesText(to: parkedCar),
                caption: distanceCaption(to: parkedCar),
                valueColor: Palette.ink
            )
        }
    }

    private var parkedAtText: String {
        guard let parkedAt = viewModel.vehicle?.parkedAt ?? viewModel.parkedCar?.parkedAt else {
            return "No car parked"
        }
        return "Parked \(parkedAt.formatted(.dateTime.month(.abbreviated).day())) at \(parkedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func floorCard(_ vehicle: ParkedVehicle) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CaptionLabel(text: "Level \(vehicle.levelCode) — Floor view")
            FindCarFloorMap(
                zones: parkingViewModel.zones,
                selectedSpotID: vehicle.spotId,
                errorMessage: parkingViewModel.errorMessage,
                isLoading: isLoadingSpots
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 8)
    }

    private func matchingParkedCar(for vehicle: ParkedVehicle) -> ParkedCar? {
        guard let parkedCar = viewModel.parkedCar,
              parkedCar.levelCode == vehicle.levelCode,
              parkedCar.spotCode == vehicle.spotCode else { return nil }
        return parkedCar
    }

    private func floorCard(_ parkedCar: ParkedCar) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CaptionLabel(text: "Level \(parkedCar.levelCode ?? "—") — Floor view")
            FindCarFloorMap(
                zones: parkingViewModel.zones,
                selectedSpotID: localSpot(for: parkedCar)?.id,
                errorMessage: parkingViewModel.errorMessage,
                isLoading: isLoadingSpots
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 8)
    }

    private func steps(levelCode: String, zone: String?, spotCode: String) -> some View {
        VStack(spacing: 8) {
            RouteStepRow(icon: "stairs", text: "Go to Level \(levelCode)")
            if let zone {
                RouteStepRow(icon: "arrow.up", text: "Walk to Zone \(zone)")
            }
            RouteStepRow(icon: "flag", text: "Your car is at spot \(spotCode)")
        }
    }

    private func localLevelTitle(for parkedCar: ParkedCar) -> String {
        let level = parkedCar.levelCode ?? "Parking level unavailable"
        guard let zone = localSpot(for: parkedCar)?.zone else { return level }
        return "\(level) · Zone \(zone)"
    }

    private func localSpot(for parkedCar: ParkedCar?) -> ParkingSpot? {
        guard let parkedCar, let levelCode = parkedCar.levelCode, let spotCode = parkedCar.spotCode else { return nil }
        return parkingViewModel.zones
            .lazy
            .flatMap(\.rows)
            .flatMap(\.spots)
            .first { $0.levelCode == levelCode && $0.code == spotCode }
    }

    private func walkingMinutesText(to parkedCar: ParkedCar?) -> String {
        guard let distance = straightLineDistance(to: parkedCar) else { return "—" }
        return "~\(LocationService.walkingMinutes(for: distance)) min"
    }

    private func distanceCaption(to parkedCar: ParkedCar?) -> String {
        if parkedCar == nil { return "No GPS when you parked" }
        guard let distance = straightLineDistance(to: parkedCar) else { return "Waiting for your location" }
        return "\(LocationService.formatted(distance)) away"
    }

    private func straightLineDistance(to parkedCar: ParkedCar?) -> CLLocationDistance? {
        guard let parkedCar, let currentLocation = locationService.currentLocation else { return nil }
        return currentLocation.distance(from: CLLocation(
            latitude: parkedCar.latitude,
            longitude: parkedCar.longitude
        ))
    }
}