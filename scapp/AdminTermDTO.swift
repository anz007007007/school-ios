import Foundation

struct AdminTermsResponseDTO: Codable {
    let items: [AdminTermDTO]
}

struct AdminTermDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let academic_year: String
    let term_type: String
    let starts_at: String
    let ends_at: String
    let is_active: Bool
}
