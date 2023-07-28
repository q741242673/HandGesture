/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's delegate object.
*/

import UIKit
import Vision

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	// アプリの起動処理
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {

		// SceneDelegate.swiftでシーンを立ち上げる
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}

// MARK: - Errors

// エラーが起きた時のエラー表示処理
enum AppError: Error {
    case captureSessionSetup(reason: String)
    case visionError(error: Error)
    case otherError(error: Error)
    
    static func display(_ error: Error, inViewController viewController: UIViewController) {
        if let appError = error as? AppError {
            appError.displayInViewController(viewController)
        } else {
            AppError.otherError(error: error).displayInViewController(viewController)
        }
    }
    
    func displayInViewController(_ viewController: UIViewController) {
        let title: String?
        let message: String?
        switch self {
        case .captureSessionSetup(let reason):
            title = "AVSession Setup Error"
            message = reason
        case .visionError(let error):
            title = "Vision Error"
            message = error.localizedDescription
        case .otherError(let error):
            title = "Error"
            message = error.localizedDescription
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        viewController.present(alert, animated: true, completion: nil)
    }
}
