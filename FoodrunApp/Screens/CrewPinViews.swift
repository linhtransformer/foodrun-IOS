import CoreLocation
import MapKit
import PhotosUI
import SwiftUI
import UIKit

// "Locatie pinnen" — the script portal's Pin a Location, from the app (HQ
// decision 0039). The crew member moves the map until the centre pin sits on
// the spot (or jumps to their own position), names it, optionally adds a note
// and a photo. The pin lands on the event — on the group, tagged with this
// truck, for grouped events — so the operator, the script portal and the
// rest of the crew see it. Only the person who placed a pin can remove it.

/// One-shot "where am I" for the pin sheet. Asks for When-In-Use permission
/// the first time (NSLocationWhenInUseUsageDescription).
@MainActor
final class CrewLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var denied = false
    @Published var locating = false
    /// Bumped on every fix, so the map re-centres even on the same spot.
    @Published var fixes = 0

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            locating = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied = true
        default:
            denied = false
            locating = true
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.denied = false
                if self.locating { self.manager.requestLocation() }
            case .denied, .restricted:
                self.denied = true
                self.locating = false
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude
        let lng = last.coordinate.longitude
        Task { @MainActor in
            self.latitude = lat
            self.longitude = lng
            self.locating = false
            self.fixes += 1
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.locating = false }
    }
}

struct CrewPinSheet: View {
    /// Where the map opens: the event's location when known.
    let startLatitude: Double?
    let startLongitude: Double?
    let onSave: (_ name: String, _ latitude: Double, _ longitude: Double, _ address: String?,
                 _ notes: String?, _ photo: Data?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var locator = CrewLocationProvider()
    @State private var position: MapCameraPosition = .automatic
    @State private var centerLatitude: Double = 52.3676
    @State private var centerLongitude: Double = 4.9041
    @State private var name = ""
    @State private var notes = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var working = false
    @State private var failed = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !working }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CrewSheetHeader(title: FRLanguage.string("pin.title")) { dismiss() }

                mapArea
                Text("pin.hint")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                if locator.denied { deniedNote }

                VStack(alignment: .leading, spacing: 6) {
                    Text("pin.name").frText(FRType.sectionHeader)
                    TextField(FRLanguage.string("pin.namePrompt"), text: $name)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("crew.prep.noteLabel").frText(FRType.sectionHeader)
                    TextField(FRLanguage.string("pin.notesPrompt"), text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
                }

                photoArea

                if failed {
                    Text("pin.failed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                }

                Button { Task { await save() } } label: {
                    ZStack {
                        if working { ProgressView().tint(Color.foodrun.backgroundInverseInk) } else { Text("pin.save") }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .opacity(canSave ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(20)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear {
            if let lat = startLatitude, let lng = startLongitude {
                centerLatitude = lat
                centerLongitude = lng
                position = .region(region(lat, lng, meters: 400))
            } else {
                position = .region(region(centerLatitude, centerLongitude, meters: 4000))
                locator.request()
            }
        }
        .onChange(of: locator.fixes) { _, _ in
            guard let lat = locator.latitude, let lng = locator.longitude else { return }
            centerLatitude = lat
            centerLongitude = lng
            withAnimation(FRAnimation.subtle) { position = .region(region(lat, lng, meters: 200)) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Map with a fixed centre pin

    private var mapArea: some View {
        Map(position: $position)
            .onMapCameraChange(frequency: .onEnd) { context in
                centerLatitude = context.region.center.latitude
                centerLongitude = context.region.center.longitude
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                Image(systemName: "mappin")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.foodrun.subject.destructive)
                    .offset(y: -17)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomTrailing) {
                Button { locator.request() } label: {
                    HStack(spacing: 6) {
                        if locator.locating {
                            ProgressView().tint(Color.foodrun.backgroundInverseInk)
                        } else {
                            Image(systemName: "location.fill")
                        }
                        Text("pin.useMyLocation")
                    }
                    // Black pill so it stands out on top of the map.
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
    }

    private var deniedNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("pin.locationDenied")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.foreground)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("pin.openSettings")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.foodrun.neuTrack))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.foodrun.subject.warning.opacity(0.12)))
    }

    @ViewBuilder
    private var photoArea: some View {
        if let photo {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button { self.photo = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.foodrun.card))
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(Text("pin.photoRemove"))
            }
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(FRLanguage.string("pin.photo"), systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(CrewCapsuleButtonStyle(filled: false))
        }
    }

    // MARK: Save

    private func save() async {
        working = true
        failed = false
        let lat = centerLatitude
        let lng = centerLongitude
        let address = await Self.address(latitude: lat, longitude: lng)
        let jpeg = photo.flatMap { CrewPhotoSheet.jpeg(from: $0) }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), lat, lng, address,
                              trimmedNotes.isEmpty ? nil : trimmedNotes, jpeg)
        working = false
        if ok { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire(); failed = true }
    }

    /// "Van Baerlestraat 3, Amsterdam" for the pin, when Apple Maps knows it.
    private static func address(latitude: Double, longitude: Double) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        guard let p = placemarks?.first else { return nil }
        let street = [p.thoroughfare, p.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        let parts = [street.isEmpty ? nil : street, p.locality].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func region(_ lat: Double, _ lng: Double, meters: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                           latitudinalMeters: meters, longitudinalMeters: meters)
    }
}
