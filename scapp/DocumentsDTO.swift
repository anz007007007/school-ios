import Foundation

struct DocumentStudentsListResponseDTO: Codable {
    let items: [DocumentStudentDTO]
}

struct DocumentStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_name: String
    let class_id: Int?
    let class_name: String?
}

struct DocumentProfilesListResponseDTO: Codable {
    let items: [DocumentProfileDTO]
}

struct DocumentProfileDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let student_name: String?
    let class_id: Int?
    let class_name: String?
    let passport_series: String?
    let passport_number: String?
    let birth_certificate: String?
    let registration_address: String?
    let residential_address: String?
    let snils: String?
    let medical_policy: String?
    let parent_full_name: String?
    let parent_phone: String?
    let notes: String?
}

struct DocumentProfileFormData: Hashable {
    let profileID: Int?
    let studentID: Int
    let passportSeries: String
    let passportNumber: String
    let birthCertificate: String
    let registrationAddress: String
    let residentialAddress: String
    let snils: String
    let medicalPolicy: String
    let parentFullName: String
    let parentPhone: String
    let notes: String
}

struct DocumentProfileSaveRequestDTO: Codable {
    let student_id: Int
    let passport_series: String?
    let passport_number: String?
    let birth_certificate: String?
    let registration_address: String?
    let residential_address: String?
    let snils: String?
    let medical_policy: String?
    let parent_full_name: String?
    let parent_phone: String?
    let notes: String?
}

struct DocumentProfileSaveResponseDTO: Codable {
    let status: String?
    let profile_id: Int?
    let message: String?
}

struct DocumentGenerateFormData: Hashable {
    let profileID: Int
    let documentType: String
    let titlePrefix: String
    let studentIDs: [Int]
}

struct DocumentGenerateRequestDTO: Codable {
    let profile_id: Int
    let document_type: String
    let title_prefix: String?
    let student_ids: [Int]?
}

struct GeneratedDocumentCreateResponseDTO: Codable {
    let status: String?
    let document_id: Int?
    let message: String?
}

struct GeneratedDocumentsListResponseDTO: Codable {
    let items: [GeneratedDocumentDTO]
}

struct GeneratedDocumentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let profile_id: Int
    let document_type: String
    let title: String
    let generated_at: String?
    let student_id: Int?
    let student_name: String?
    let content: String?
}

struct PublicDocumentsListResponseDTO: Codable {
    let items: [PublicDocumentDTO]
}

struct PublicDocumentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let document_type: String
    let is_public: Bool
    let content: String?
    let file_url: String?
    let created_at: String?
}

struct PublicDocumentFormData: Hashable {
    let title: String
    let documentType: String
    let isPublic: Bool
    let content: String
    let fileURL: String
}

struct PublicDocumentCreateRequestDTO: Codable {
    let title: String
    let document_type: String?
    let is_public: Bool?
    let content: String?
    let file_url: String?
}

struct PublicDocumentUpdateRequestDTO: Codable {
    let title: String
    let document_type: String?
    let is_public: Bool?
    let content: String?
    let file_url: String?
}

struct DocumentStatusResponseDTO: Codable {
    let status: String?
    let message: String?
}

struct PublicDocumentIDStatusResponseDTO: Codable {
    let status: String?
    let document_id: Int?
    let message: String?
}