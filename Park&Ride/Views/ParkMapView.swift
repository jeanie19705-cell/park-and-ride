import SwiftUI
import MapKit

struct ParkMapView: View {
    let viewModel: ParkingViewModel

    private var carParks: [BackendCarPark] { viewModel.carParks }

    @State private var locationManager = LocationManager()
    @State private var selectedPark: BackendCarPark?
    @State private var hasInitiallycentered = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.87, longitude: 151.21),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(carParks) { park in
                if let coord = coordinate(for: park) {
                    Annotation(park.facility_name ?? "", coordinate: coord, anchor: .bottom) {
                        ParkPin(carPark: park)
                            .onTapGesture { selectedPark = park }
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onChange(of: locationManager.userLocation) { _, location in
            guard let location, !hasInitiallycentered else { return }
            hasInitiallycentered = true
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ))
            }
        }
        .sheet(item: $selectedPark) { park in
            NavigationStack {
                CarParkDetailView(carPark: park)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                viewModel.togglePin(park)
                            } label: {
                                Label(
                                    viewModel.isPinned(park) ? "Unfavourite" : "Favourite",
                                    systemImage: viewModel.isPinned(park) ? "star.fill" : "star"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func coordinate(for park: BackendCarPark) -> CLLocationCoordinate2D? {
        guard let latStr = park.location?.latitude, let lonStr = park.location?.longitude,
              let lat = Double(latStr), let lon = Double(lonStr) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct ParkPin: View {
    let carPark: BackendCarPark

    private var color: Color {
        guard let f = carPark.occupancyFraction else { return .gray }
        if f < 0.60 { return .green }
        if f < 0.85 { return .orange }
        return .occupancyRed
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .shadow(radius: 2)
                if let available = carPark.availableSpots {
                    Text("\(available)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "parkingsign")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(color)
                .offset(y: -2)
        }
    }
}