import CoreLocation
import SwiftUI

struct FindCarView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @ObservedObject var locationService: LocationService
    let destinationID: String?
    @StateObject private var parkingViewModel: ParkingMapViewModel
    @State private var mode: RouteMode = .direct
    @State private var isLoadingSpots = false

    init(
        viewModel: ReservationViewModel,
        parkingService: ParkingServicing,
        locationService: LocationService,
        destinationID: String?
    ) {
        self.viewModel = viewModel
        self.locationService = locationService
        self.destinationID = destinationID
        _parkingViewModel = StateObject(
            wrappedValue: ParkingMapViewModel(service: parkingService, destination: destinationID)
        )
    }

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
                        summary(
                            spotCode: vehicle.spotCode,
                            levelTitle: "\(vehicle.levelCode) · Zone \(vehicle.zone)",
                            parkedCar: matchingParkedCar(for: vehicle)
                        )
                        floorCard(vehicle)
                        modePicker
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
                        modePicker
                        steps(
                            levelCode: parkedCar.levelCode ?? "",
                            zone: localSpot(for: parkedCar)?.zone,
                            spotCode: parkedCar.spotCode ?? "—"
                        )
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
        .task(id: (vehicleLevelCode ?? "") + (destinationID ?? "")) {
            guard let vehicleLevelCode else { return }
            parkingViewModel.destination = destinationID
            isLoadingSpots = true
            defer { isLoadingSpots = false }
            await parkingViewModel.refresh(levelCode: vehicleLevelCode)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find my car")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(parkedAtText)
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

    private var vehicleLevelCode: String? {
        viewModel.vehicle?.levelCode ?? viewModel.parkedCar?.levelCode
    }

    private func summary(spotCode: String, levelTitle: String, parkedCar: ParkedCar?) -> some View {
        HStack(spacing: 12) {
            SummaryTile(
                label: "Spot",
                value: spotCode,
                caption: levelTitle,
                valueColor: Palette.accent,
                monospaced: true
            )
            SummaryTile(
                label: "Walk",
                value: distanceText(to: parkedCar),
                caption: walkingEstimateText(to: parkedCar),
                valueColor: Palette.ink
            )
        }
    }

    private var parkedAtText: String {
        if let vehicle = viewModel.vehicle {
            return vehicle.parkedAt.formatted(date: .abbreviated, time: .shortened)
        }
        if let parkedCar = viewModel.parkedCar {
            return parkedCar.parkedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Vehicle location"
    }

    private func floorCard(_ vehicle: ParkedVehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CaptionLabel(text: "\(vehicle.levelCode) · Zone \(vehicle.zone) — Floor view")
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
        VStack(alignment: .leading, spacing: 14) {
            CaptionLabel(text: "\(localLevelTitle(for: parkedCar)) — Floor view")
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

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(RouteMode.allCases) { item in
                RouteModeButton(title: item.title, isSelected: mode == item) {
                    mode = item
                }
                .disabled(true)
            }
        }
    }

    private func steps(levelCode: String, zone: String?, spotCode: String) -> some View {
        VStack(spacing: 8) {
            RouteStepRow(icon: "square.3.layers.3d", text: "Level \(levelCode)")
            if let zone {
                RouteStepRow(icon: "mappin.and.ellipse", text: "Zone \(zone) · Spot \(spotCode)")
            } else {
                RouteStepRow(icon: "mappin.and.ellipse", text: "Spot \(spotCode)")
            }
            RouteStepRow(icon: "point.topleft.down.to.point.bottomright.curvepath", text: "Turn-by-turn directions unavailable.")
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

    private func distanceText(to parkedCar: ParkedCar?) -> String {
        guard let distance = straightLineDistance(to: parkedCar) else { return "—" }
        return LocationService.formatted(distance)
    }

    private func walkingEstimateText(to parkedCar: ParkedCar?) -> String {
        guard let distance = straightLineDistance(to: parkedCar) else { return "Distance unavailable" }
        let minutes = LocationService.walkingMinutes(for: distance)
        return "~\(minutes) min · straight-line estimate"
    }

    private func straightLineDistance(to parkedCar: ParkedCar?) -> CLLocationDistance? {
        guard let parkedCar, let currentLocation = locationService.currentLocation else { return nil }
        return currentLocation.distance(from: CLLocation(
            latitude: parkedCar.latitude,
            longitude: parkedCar.longitude
        ))
    }
}