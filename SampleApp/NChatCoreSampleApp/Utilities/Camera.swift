import MobileCoreServices
import Photos
import PhotosUI
import UIKit

protocol CameraProtocol {
    func presentSourceSelection(type: UIImagePickerController.SourceType)
}

final class Camera: NSObject {

    private var completion: ((Camera, UIImage?) -> Void)!
    private var picker: UIViewController?
    private var image: UIImage?

    private weak var presentingViewController: UIViewController?

    static var isPhotoLibraryAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    init(_ presentingViewController: UIViewController, completion: @escaping (Camera, UIImage?) -> Void) {
        self.presentingViewController = presentingViewController
        super.init()
        self.completion = { camera, image in
            self.dismissImagePickerIfNeeded {
                completion(camera, image)
            }
        }
    }
}

extension Camera: CameraProtocol {

    func presentSourceSelection(type: UIImagePickerController.SourceType) {
        if type == .camera {
            Permission.camera.request { permissionResult in
                DispatchQueue.main.async {
                    switch permissionResult {
                    case .approved: self.presentImagePickerViewController(type: type)
                    default: self.presentAuthorizationAlert(for: type)
                    }
                }
            }
        } else {
            Permission.photoLibrary.request { permissionResult in
                DispatchQueue.main.async {
                    switch permissionResult {
                    case .approved: self.showAppropriatePicker(type: type)
                    case .limited: self.presentAuthorizationAlert(for: .photoLibrary)
                    default: self.presentAuthorizationAlert(for: type)
                    }
                }
            }
        }
    }

    private func dismissImagePickerIfNeeded(completion: @escaping () -> Void) {
        guard let picker = picker else {
            completion()
            return
        }
        picker.dismiss(animated: false, completion: completion)
    }

    private func showAppropriatePicker(type: UIImagePickerController.SourceType) {
        if #available(iOS 14, *) {
            presentPhotoLibraryView()
        } else {
            presentImagePickerViewController(type: type)
        }
    }

    private func presentImagePickerViewController(type: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = type
        picker.mediaTypes = [kUTTypeImage as String]
        self.picker = picker
        presentingViewController?.present(picker, animated: true)
    }

    @available(iOS 14, *)
    private func presentPhotoLibraryView() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        self.picker = pickerViewController
        presentingViewController?.present(pickerViewController, animated: true)
    }

    private func presentAuthorizationAlert(for sourceType: UIImagePickerController.SourceType) {
        let alertController = UIAlertController(title: nil,
                                                message: sourceType == .camera ? "The app does not have permission to access the camera. Do you want to change it in iOS Settings?" : "The app does not have permission to access the photo library. Do you want to change it in iOS Settings?",
                                                preferredStyle: .alert)
        alertController.addAction(.init(title: "Cancel", style: .default) { _ in })
        alertController.addAction(.init(title: "Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })

        presentingViewController?.present(alertController, animated: true)
    }
}

extension Camera: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completion(self, nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let mediaType = info[.mediaType] as? String,
            mediaType == kUTTypeImage as String,
            let image = info[.originalImage] as? UIImage else {
                completion(self, nil)
                return
        }

        self.image = image
        completion(self, image)
    }
}

@available(iOS 14, *)
extension Camera: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let completion: (UIImage?) -> Void = { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.image = image
                self.completion(self, image)
            }
        }
        guard let itemProvider = results.first?.itemProvider,
              itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            completion(nil)
            return
        }

        itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { image, _ in
            completion(image as? UIImage)
        })
    }
}
