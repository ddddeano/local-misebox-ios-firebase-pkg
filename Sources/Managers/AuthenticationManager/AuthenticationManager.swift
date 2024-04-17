//
//  AuthenticationManager.swift
//
//
//  Created by Daniel Watson on 01.03.2024.
//
import Foundation
import Firebase
import FirebaseAuth

public class AuthenticationManager: ObservableObject {

        public struct FirebaseUser {
            public let uid: String
            public let email: String?
            public let firstName: String
            public let lastName: String
            public let photoUrl: String?
            public let isAnon: Bool
            public var provider: AuthenticationMethod = .unknown

            public init(user: User) {
                self.uid = user.uid
                self.email = user.email
                
                if let displayName = user.displayName {
                    let nameComponents = displayName.components(separatedBy: " ")
                    self.firstName = nameComponents.first ?? ""
                    self.lastName = nameComponents.last ?? ""
                } else {
                    self.firstName = ""
                    self.lastName = ""
                }

                self.photoUrl = user.photoURL?.absoluteString
                self.isAnon = user.isAnonymous

                // Determine the actual provider by checking the providerData
                for userInfo in user.providerData {
                    self.provider = AuthenticationMethod(rawValue: userInfo.providerID)
                    print("Determined AuthenticationMethod: \(self.provider.rawValue)")
                    break  // Assume the first non-unknown provider is the one we want
                }
            }
        }
    
    @Published public var authError: Error?
    enum CustomError: Error {
        case credentialAlreadyInUse
        // Add other custom error cases as needed
    }
    
    public init() {}
    
    public func authenticate() async throws -> FirebaseUser {
        if let currentUser = Auth.auth().currentUser {
            return FirebaseUser(user: currentUser)
        } else {
            return try await signInAnon()
        }
    }
    
    @discardableResult
    public func signInAnon() async throws -> FirebaseUser {
        let authResultData = try await Auth.auth().signInAnonymously()
        return FirebaseUser(user: authResultData.user)
    }

    public func signOut() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    public func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badURL)
        }
        try await user.delete()
    }
}

// MARK: - Account Processing

extension AuthenticationManager {
    @discardableResult
       public func processWithEmail(email: String, password: String, intent: UserIntent) async throws -> FirebaseUser {
           let credential = EmailAuthProvider.credential(withEmail: email, password: password)
           
           if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
               return try await linkCredential(credential: credential)
           } else {
               switch intent {
               case .newUser:
                   return try await createWithEmail(email: email, password: password)
               case .returningUser:
                   do {
                       return try await signInWithEmail(email: email, password: password)
                   } catch CustomError.credentialAlreadyInUse {
                       // If signing in fails because the credential is already in use, attempt to sign in directly.
                       print("Credential already in use with a different account. Attempting to sign in directly.")
                       return try await signIn(credential: credential)
                   }
               }
           }
       }

    
    @discardableResult
    public func processWithGoogle(tokens: GoogleSignInResultModel) async throws -> FirebaseUser {
        let credential = GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
        
        do {
            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                // Attempt to link the credential with the current anonymous user.
                return try await linkCredential(credential: credential)
            } else {
                // No anonymous user to link, proceed to sign in directly.
                return try await signIn(credential: credential)
            }
        } catch CustomError.credentialAlreadyInUse {
            // If linking fails because the credential is already in use, attempt to sign in directly.
            print("Credential already in use with a different account. Attempting to sign in directly.")
            return try await signIn(credential: credential)
        } catch {
            // Handle any other errors that might occur.
            throw error
        }
    }


     
    @discardableResult
    public func processWithApple(tokens: SignInWithAppleResult) async throws -> FirebaseUser {
        let credential = OAuthProvider.credential(withProviderID: AuthenticationMethod.apple.rawValue, idToken: tokens.token, rawNonce: tokens.nonce)
        
        do {
            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                return try await linkCredential(credential: credential)
            } else {
                return try await signIn(credential: credential)
            }
        } catch CustomError.credentialAlreadyInUse {
            // If signing in fails because the credential is already in use, attempt to sign in directly.
            print("Credential already in use with a different account. Attempting to sign in directly.")
            return try await signIn(credential: credential)
        }
    }


     public func signIn(credential: AuthCredential) async throws -> FirebaseUser {
         let authDataResult = try await Auth.auth().signIn(with: credential)
         return FirebaseUser(user: authDataResult.user)
     }
}

// MARK: - Account Creation
extension AuthenticationManager {
    @discardableResult
    public func createWithEmail(email: String, password: String) async throws -> FirebaseUser {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return FirebaseUser(user: authResult.user)
    }
}

// MARK: - Account Return
extension AuthenticationManager {
    public func signInWithEmail(email: String, password: String) async throws -> FirebaseUser {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return FirebaseUser(user: authResult.user)
    }
}
// MARK: - Account Linking
extension AuthenticationManager {
    
    @discardableResult
    public func linkEmail(email: String, password: String) async throws -> FirebaseUser {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        return try await linkCredential(credential: credential)
    }
    @discardableResult
    public func linkGoogle(tokens: GoogleSignInResultModel) async throws -> FirebaseUser {
        let credential = GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
        return try await linkCredential(credential: credential)
    }
    @discardableResult
    public func linkApple(tokens: SignInWithAppleResult) async throws -> FirebaseUser {
        let credential = OAuthProvider.credential(withProviderID: AuthenticationMethod.apple.rawValue, idToken: tokens.token, rawNonce: tokens.nonce)
        return try await linkCredential(credential: credential)
    }
    
    private func linkCredential(credential: AuthCredential) async throws -> FirebaseUser {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badURL) // It might be better to define your own error type for clarity.
        }
        
        do {
            let authDataResult = try await user.link(with: credential)
            return FirebaseUser(user: authDataResult.user)
        } catch let error as NSError {
            // Check if the error is due to the credential already being associated with a different account.
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Handle the specific error, e.g., informing the user or initiating account recovery/merge.
                throw CustomError.credentialAlreadyInUse // Define CustomError to include this case.
            } else {
                // Re-throw the error if it's not the specific case we're looking for.
                throw error
            }
        }
    }

}

// MARK: - Helper functions
extension AuthenticationManager {
    
}
// MARK: - Helper Structures
extension AuthenticationManager {
    
    public enum UserIntent: String, CaseIterable, Identifiable {
        case newUser = "New User"
        case returningUser = "Returning User"
        
        public var id: String { self.rawValue }
    }
    
    public enum AuthenticationMethod: String {
        case anon = "anonymous"
        case email = "email"
        case google = "google.com"
        case apple = "apple.com"
        case unknown
        
        public init(rawValue: String) {
            switch rawValue {
            case AuthenticationMethod.anon.rawValue:
                self = .anon
            case AuthenticationMethod.email.rawValue:
                self = .email
            case AuthenticationMethod.google.rawValue:
                self = .google
            case AuthenticationMethod.apple.rawValue:
                self = .apple
            default:
                self = .unknown
            }
        }
    }
    
    public struct GoogleSignInResultModel {
        public let idToken: String
        public let accessToken: String
        public let name: String?
        public let email: String?
    }
}
