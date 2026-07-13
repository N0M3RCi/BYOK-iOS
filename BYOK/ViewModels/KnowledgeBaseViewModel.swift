import Foundation
import SwiftUI

@MainActor
final class KnowledgeBaseViewModel: ObservableObject {
    @Published var knowledgeBases: [KnowledgeBase] = []
    @Published var documents: [KnowledgeDocument] = [KnowledgeDocument]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false

    private let apiClient = APIClient.shared

    func loadKnowledgeBases() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response: [KnowledgeBase] = try await apiClient.getKnowledgeBases()
                knowledgeBases = response
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func createKnowledgeBase(name: String, description: String?) async {
        do {
            let _ = try await apiClient.createKnowledgeBase(name: name, description: description)
            loadKnowledgeBases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteKnowledgeBase(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let kb = knowledgeBases[index]
                do {
                    let _: EmptyResponse = try await apiClient.deleteKnowledgeBase(id: kb.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            loadKnowledgeBases()
        }
    }

    func loadDocuments(knowledgeBaseId: String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response: [KnowledgeDocument] = try await apiClient.getKnowledgeBaseDocuments(knowledgeBaseId: knowledgeBaseId)
                documents = response
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func uploadDocument(knowledgeBaseId: String, data: Data, filename: String) async {
        isUploading = true
        uploadProgress = 0
        errorMessage = nil
        do {
            let _ = try await apiClient.uploadKnowledgeDocument(knowledgeBaseId: knowledgeBaseId, data: data, filename: filename)
            uploadProgress = 1.0
            loadDocuments(knowledgeBaseId: knowledgeBaseId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }

    func deleteDocument(knowledgeBaseId: String, at offsets: IndexSet) {
        Task {
            for index in offsets {
                let doc = documents[index]
                do {
                    let _: EmptyResponse = try await apiClient.deleteKnowledgeDocument(knowledgeBaseId: knowledgeBaseId, documentId: doc.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            loadDocuments(knowledgeBaseId: knowledgeBaseId)
        }
    }
}