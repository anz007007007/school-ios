import Foundation

struct AdminSubjectsResponseDTO: Codable {
    let items: [AdminSubjectDTO]
}

struct AdminSubjectDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}
