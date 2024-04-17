//
//  FirestoreManager.swift
//
//  Created by Daniel Watson on 01.04.2024.
//

import Foundation
import Firebase
import FirebaseFirestore

public class FirestoreManager {
    private let db = Firestore.firestore()
    public init() {}
    
    public enum FirestoreError: Error {
        case unknown, invalidSnapshot, networkError, documentNotFound
    }
    
    public func fetchDataDocument<T: FirestoreDataProtocol>(collection: String, documentID: String, completion: @escaping (Result<T, Error>) -> Void) {
        let docRef = db.collection(collection).document(documentID)
        docRef.getDocument { documentSnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documentSnapshot = documentSnapshot, documentSnapshot.exists else {
                completion(.failure(FirestoreError.documentNotFound))
                return
            }
            if let dataModel = T(documentSnapshot: documentSnapshot) {
                completion(.success(dataModel))
            } else {
                completion(.failure(FirestoreError.invalidSnapshot))
            }
        }
    }
    
    public func fetchDocument<T: FirestoreEntity>(for entity: T) async throws -> T? {
        let docRef = db.collection(entity.collection).document(entity.id)
        let documentSnapshot = try await docRef.getDocument()
        guard documentSnapshot.exists, let entity = T(documentSnapshot: documentSnapshot) else {
            return nil
        }
        return entity
    }
    
    @discardableResult
    public func updateDocument<T: FirestoreEntity>(for entity: T, merge: Bool = true) async -> Result<Void, Error> {
        let docRef = db.collection(entity.collection).document(entity.id)
        let updateData = entity.toFirestore()
        do {
            try await docRef.setData(updateData, merge: merge)
            return .success(())
        } catch let error {
            return .failure(error)
        }
    }
    
    public func addDocumentListener<T: Listenable>(for entity: T, completion: @escaping (Result<T, Error>) -> Void) -> ListenerRegistration {
        let docRef = db.collection(entity.collection).document(entity.id)
        return docRef.addSnapshotListener { documentSnapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let document = documentSnapshot else {
                    completion(.failure(FirestoreError.documentNotFound))
                    return
                }
                if let data = document.data(), document.exists {
                    var updatedEntity = entity
                    updatedEntity.update(with: data)
                    completion(.success(updatedEntity))
                } else {
                    completion(.failure(FirestoreError.documentNotFound))
                }
            }
        }
    }
    public func addCollectionListener<T: FirestoreEntity>(collection: String, completion: @escaping (Result<[T], Error>) -> Void) -> ListenerRegistration {
        let collectionRef = db.collection(collection)
        return collectionRef.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let snapshot = querySnapshot else {
                completion(.failure(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Snapshot is nil"])))
                return
            }
            var entities = [T]()
            for document in snapshot.documents {
                if let entity = T(documentSnapshot: document) {
                    entities.append(entity)
                }
            }
            completion(.success(entities))
        }
    }
    
    public func checkDocumentExists(collection: String, documentID: String) async throws -> Bool {
        let docRef = db.collection(collection).document(documentID)
        let documentSnapshot = try await docRef.getDocument()
        return documentSnapshot.exists
    }
    public func setDoc<T: FirestoreEntity>(entity: T) async throws {
        let docRef = db.collection(entity.collection).document(entity.id)
        print("Document Reference: \(docRef.path)")
        try await docRef.setData(entity.toFirestore())
    }
    
    public func isFieldValueUnique(inCollection collection: String, fieldName: String, fieldValue: String) async throws -> Bool {
        let querySnapshot = try await db.collection(collection).whereField(fieldName, isEqualTo: fieldValue).getDocuments()
        // If the query returns no documents, the field value is unique
        return querySnapshot.documents.isEmpty
    }

    public func updateDocumentField(collection: String, documentID: String, data: [String: Any], merge: Bool = true) async -> Result<Void, Error> {
        let docRef = db.collection(collection).document(documentID)
        
        do {
            try await docRef.setData(data, merge: merge)
            print("[FirestoreManager] Document successfully updated.")
            return .success(())
        } catch let error {
            print("[FirestoreManager] Error updating document: \(error.localizedDescription)")
            return .failure(error)
        }
    }

}

public protocol FirestoreDataProtocol {
    init?(documentSnapshot: DocumentSnapshot)
    func update(with data: [String: Any])
}

public protocol FirestoreEntity {
    var doc: String { get }
    var collection: String { get }
    var id: String { get set }
    init?(documentSnapshot: DocumentSnapshot)
    func toFirestore() -> [String: Any]
}

public protocol Listenable: FirestoreEntity {
    mutating func update(with data: [String: Any])
}

public func fireObject<T>(from dictionaryData: [String: Any], using initializer: (Dictionary<String, Any>) -> T?) -> T? {
    return initializer(dictionaryData)
}
public func fireArray<T>(from arrayData: [[String: Any]], using initializer: (Dictionary<String, Any>) -> T?) -> [T] {
    return arrayData.compactMap(initializer)
}
