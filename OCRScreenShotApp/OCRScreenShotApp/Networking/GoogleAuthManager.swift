import Foundation
import AuthenticationServices
import UIKit

class GoogleAuthManager: NSObject, ObservableObject {
    static let shared = GoogleAuthManager()

    @Published private(set) var idToken: String?

    private let tokenKey = "GoogleIDToken"
    private var session: ASWebAuthenticationSession?
    private var anchorProvider: AnchorProvider?

    private override init() {
        idToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    func signIn(presenting viewController: UIViewController) {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String else {
            print("CLIENT_ID missing from Info.plist")
            return
        }

        let scheme = "com.googleusercontent.apps.\(clientID)"
        let redirectURI = "\(scheme):/oauthredirect"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "id_token"),
            URLQueryItem(name: "scope", value: "openid email"),
            URLQueryItem(name: "nonce", value: UUID().uuidString)
        ]
        guard let url = components.url else { return }

        anchorProvider = AnchorProvider(viewController: viewController)
        session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let callbackURL, let fragment = callbackURL.fragment,
               let token = Self.extractToken(from: fragment) {
                DispatchQueue.main.async {
                    self.idToken = token
                    UserDefaults.standard.set(token, forKey: self.tokenKey)
                }
            } else if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
            }
        }
        session?.presentationContextProvider = anchorProvider
        session?.prefersEphemeralWebBrowserSession = true
        session?.start()
    }

    func signOut() {
        idToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    var isSignedIn: Bool {
        idToken != nil
    }

    private static func extractToken(from fragment: String) -> String? {
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=")
            if parts.count == 2 && parts[0] == "id_token" {
                return String(parts[1])
            }
        }
        return nil
    }
}

private class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        viewController?.view.window ?? ASPresentationAnchor()
    }
}
