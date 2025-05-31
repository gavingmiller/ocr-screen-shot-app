import Foundation
import GoogleSignIn
import UIKit

class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()
    @Published private(set) var user: GIDGoogleUser?

    private init() {
        restorePreviousSignIn()
    }

    func signIn(presenting viewController: UIViewController) {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String else {
            print("CLIENT_ID missing from Info.plist")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }
            self?.user = result?.user
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        user = nil
    }

    private func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user {
                self?.user = user
            } else if let error = error {
                print("Restore sign-in failed: \(error.localizedDescription)")
            }
        }
    }

    var isSignedIn: Bool {
        user != nil
    }

    var idToken: String? {
        user?.idToken?.tokenString
    }
}
