//
//  File.swift
//  
//
//  Created by Daniel Watson on 20.02.2024.
//

import FirebaseStorage
import SwiftUI

public class FirebaseStorageManager {
    public static let shared = FirebaseStorageManager() // Make shared public

    private init() {} // Keep the initializer private to prevent external instantiation

    public func uploadImage(imageData: Data, inDirectory directory: String) async throws -> String {
        let uid = generateShortUID(length: 6)
        let fileName = "\(uid).jpg"
        let storageRef = Storage.storage().reference()
        let imagePath = "\(directory)/\(fileName)"
        let imageRef = storageRef.child(imagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw error
        }
    }

    private func generateShortUID(length: Int) -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(length).lowercased()
    }

    // Additional storage utility methods can be added here
}

