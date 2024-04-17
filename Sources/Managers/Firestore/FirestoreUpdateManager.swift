//
//  File.swift
//  
//
//  Created by Daniel Watson on 04.02.2024.
//
import Foundation
import FirebaseFirestore

public protocol Updatable {
    func toFirestore() -> [String: Any]
}
public class FirestoreUpdateManager {
    private let db = Firestore.firestore()
    public init() {}

    public enum FirestoreFieldValueOperation {
        case arrayUnion(Any)
        case arrayRemove(Any)
        case replaceArray(Any)
    }
    public func documentReference(forCollection collection: String, documentID: String) -> DocumentReference {
        return db.collection(collection).document(documentID)
    }
    
    /*public func updateDocument<T: FirestoreEntity, U: Updatable>(for entity: T, with updateData: U, merge: Bool = true) async throws {
        let docRef = documentReference(forCollection: entity.collection, documentID: entity.id)
        let data = updateData.toFirestore()
        
        do {
            try await docRef.setData(data, merge: merge)
        } catch let error {
            print("FirestoreUpdateManager[updateDocument] Error updating document: \(error.localizedDescription)")
            throw error
        }
    }*/
    
    public func updateDocumentSection(collection: String, documentID: String, section: String, updateData: [String: Any]) async throws {
        let docRef = db.collection(collection).document(documentID)
        let dataToUpdate = [section: updateData]
        do {
            try await docRef.updateData(dataToUpdate)
        } catch let error {
            print("FirestoreUpdateManager[updateDocumentSection] Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updateDependentArray(forCollection collection: String, documentID: String, fieldName: String, newValue: [[String: Any]]) async throws {
            let documentRef = db.collection(collection).document(documentID)
            try await documentRef.updateData([fieldName: newValue])
        }
    
    public func updateDocumentDependant(collection: String, documentID: String, field: String, value: Any, operation: FirestoreFieldValueOperation) async throws {
        let docRef = db.collection(collection).document(documentID)
        let updateData: [String: Any]
        switch operation {
        case .arrayUnion(let unionValue):
            updateData = [field: FieldValue.arrayUnion([unionValue])]
        case .arrayRemove(let removeValue):
            updateData = [field: FieldValue.arrayRemove([removeValue])]
        case .replaceArray(let newValue):
            updateData = [field: newValue]
        }
        do {
            try await docRef.updateData(updateData)
        } catch let error {
            print("FirestoreUpdateManager[updateDocumentDependant] Error: \(error.localizedDescription)")
            throw error
        }
    }
}
