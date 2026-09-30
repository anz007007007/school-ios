import Foundation

struct AdminUsersResponseDTO: Codable {
    let items: [AdminUserDTO]
}

struct AdminUserDTO: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let full_name: String
    let is_active: Bool
    let role_code: String
    let role_name: String
}
