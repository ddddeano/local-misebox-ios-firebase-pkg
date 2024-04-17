//
//  File.swift
//  
//
//  Created by Daniel Watson on 12.02.2024.
//

import Foundation
import GoogleSignIn
import GoogleSignInSwift

public final class SignInGoogleHelper {

    public init() {}

    @MainActor
    public func signIn() async throws -> AuthenticationManager.GoogleSignInResultModel {
        guard let topVC = FirebaseUtilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = gidSignInResult.user.accessToken.tokenString
        let name = gidSignInResult.user.profile?.name
        let email = gidSignInResult.user.profile?.email

        let tokens = AuthenticationManager.GoogleSignInResultModel(idToken: idToken, accessToken: accessToken, name: name, email: email)
        return tokens
    }
}
