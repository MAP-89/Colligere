import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var locationName: String?

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pin: CLLocationCoordinate2D?
    @State private var pinLabel: String = ""
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isResolvingName = false
    @State private var statusMessage: String?
    @State private var isFetchingLocation = false
    @State private var fetcher = LocationFetcher()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapView
                searchOverlay
            }
            .navigationTitle("Field Work Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(pin == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomPanel
            }
        }
        .onAppear { initializeFromBindings() }
    }

    // MARK: - Map

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let pin {
                    Marker(pinLabel.isEmpty ? "Selected" : pinLabel, coordinate: pin)
                        .tint(.red)
                }
                UserAnnotation()
            }
            .mapControls { MapCompass() }
            .onTapGesture { localPoint in
                if let coord = proxy.convert(localPoint, from: .local) {
                    searchResults = []
                    placePin(at: coord)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Search

    private var searchOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search for a place", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit { performSearch() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(6).enumerated()), id: \.offset) { _, item in
                        Button {
                            select(item: item)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.red)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    let sub = subtitleFor(item)
                                    if !sub.isEmpty {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if item != searchResults.prefix(6).last {
                            Divider()
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pin {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pinLabel.isEmpty ? "Pinned location" : pinLabel)
                            .font(.subheadline.weight(.medium))
                        Text(String(format: "%.4f, %.4f", pin.latitude, pin.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isResolvingName {
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                Text("Tap the map, search a place, or use your current location to mark where this language is spoken.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await useCurrentLocation() }
            } label: {
                HStack {
                    if isFetchingLocation {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text(isFetchingLocation ? "Getting location…" : "Use Current Location")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isFetchingLocation)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func initializeFromBindings() {
        if let lat = latitude, let lng = longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            pin = coord
            pinLabel = locationName ?? ""
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            ))
        }
    }

    private func saveAndDismiss() {
        if let pin {
            latitude = pin.latitude
            longitude = pin.longitude
            locationName = pinLabel.isEmpty ? nil : pinLabel
        }
        dismiss()
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            do {
                let response = try await MKLocalSearch(request: request).start()
                searchResults = response.mapItems
            } catch {
                searchResults = []
            }
        }
    }

    private func select(item: MKMapItem) {
        let coord = item.location.coordinate
        pin = coord
        pinLabel = formattedLabel(for: item)
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
        searchResults = []
        searchText = ""
    }

    private func placePin(at coord: CLLocationCoordinate2D) {
        pin = coord
        pinLabel = ""
        isResolvingName = true
        Task {
            let label = await reverseGeocode(coord)
            pinLabel = label ?? ""
            isResolvingName = false
        }
    }

    private func useCurrentLocation() async {
        isFetchingLocation = true
        statusMessage = nil
        defer { isFetchingLocation = false }

        guard let coord = await fetcher.fetch() else {
            statusMessage = "Couldn't get your location. Make sure location access is enabled, or pick a spot on the map."
            return
        }
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        ))
        placePin(at: coord)
    }

    // MARK: - Helpers

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        let mapItems = (try? await request.mapItems) ?? []
        guard let item = mapItems.first else { return nil }

        if let context = item.addressRepresentations?.cityWithContext(.full),
           !context.isEmpty {
            return context
        }
        if let shortAddress = item.address?.shortAddress, !shortAddress.isEmpty {
            return shortAddress
        }
        return item.name
    }

    private func formattedLabel(for item: MKMapItem) -> String {
        var parts: [String] = []
        if let name = item.name, !name.isEmpty {
            parts.append(name)
        }
        if let context = item.addressRepresentations?.cityWithContext(.full),
           !context.isEmpty {
            parts.append(context)
        }
        return parts.joined(separator: ", ")
    }

    private func subtitleFor(_ item: MKMapItem) -> String {
        item.addressRepresentations?.cityWithContext(.full) ?? ""
    }
}

// MARK: - LocationFetcher

@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetch() async -> CLLocationCoordinate2D? {
        if let existing = continuation {
            existing.resume(returning: nil)
            continuation = nil
        }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            requestNext()
        }
    }

    private func requestNext() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            finish(nil)
        }
    }

    private func finish(_ coord: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coord)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if self.continuation != nil {
                self.requestNext()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        Task { @MainActor in
            self.finish(coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.finish(nil)
        }
    }
}
