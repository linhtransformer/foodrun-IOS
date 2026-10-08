import PhotosUI
import SwiftUI
import UIKit

// Photo tasks ("Foto maken" in HQ): take a picture with the camera or pick one
// from the library. The image is downscaled to max 1600 px and uploaded as JPEG
// to the private crew-task-photos bucket; the operator sees it on the answer.

struct CrewPhotoSheet: View {
    let title: String
    let prompt: String?
    let existingPath: String?
    let onSave: (_ jpeg: Data) async -> Bool
    let onClear: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var preview: UIImage?
    @State private var existingURL: URL?
    @State private var working = false
    @State private var failed = false

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: title).font(.system(size: 22, weight: .bold))
            if let prompt, !prompt.isEmpty {
                Text(verbatim: prompt).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }

            photoArea

            if failed {
                Text("crew.photo.failed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.foodrun.subject.destructive)
            }

            HStack(spacing: 10) {
                if cameraAvailable {
                    Button { showCamera = true } label: {
                        Label(FRLanguage.string("crew.photo.take"), systemImage: "camera")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(CrewCapsuleButtonStyle(filled: true))
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(FRLanguage.string("crew.photo.library"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(CrewCapsuleButtonStyle(filled: !cameraAvailable))
            }
            .disabled(working)

            if existingPath != nil {
                Button {
                    Task {
                        working = true
                        let ok = await onClear()
                        working = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text("crew.answer.clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(working)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            if let existingPath { existingURL = try? await CrewAPI.photoURL(existingPath) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil   // so picking the same photo again fires onChange
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await submit(image)
                } else {
                    failed = true
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { Task { await submit(image) } }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
            if let preview {
                Image(uiImage: preview).resizable().scaledToFit()
            } else if let existingURL {
                AsyncImage(url: existingURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() } else { ProgressView() }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 34, weight: .light))
                    Text("crew.photo.empty").frText(FRType.rowSubtitle)
                }
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            if working {
                Color.foodrun.foreground.opacity(0.25)
                ProgressView().tint(Color.foodrun.backgroundInverseInk)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous))
    }

    private func submit(_ image: UIImage) async {
        guard let jpeg = CrewPhotoSheet.jpeg(from: image) else { failed = true; return }
        preview = image
        failed = false
        working = true
        let ok = await onSave(jpeg)
        working = false
        if ok { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire(); failed = true }
    }

    /// Downscale to max 1600 px on the long side and encode as JPEG.
    static func jpeg(from image: UIImage, maxSide: CGFloat = 1600) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}

/// Full-screen camera (UIImagePickerController). Needs NSCameraUsageDescription.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// Black (filled) or outlined capsule, the app's CTA look.
struct CrewCapsuleButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(filled ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
            .background(Capsule().fill(filled ? Color.foodrun.foreground : Color.clear))
            .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: filled ? 0 : 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
