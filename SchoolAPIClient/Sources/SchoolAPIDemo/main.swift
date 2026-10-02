import Foundation
import SchoolAPIClient

@main
struct APIDemo {
    static func main() async throws {
        let api = SchoolAPI(baseURL: URL(string: "http://83.217.13.81")!)

        do {
            // 1. Health check
            let health = try await api.healthCheck()
            print("✅ Status: \(health.status), Env: \(health.environment)")

            // 2. Login
            let token = try await api.login(login: "anz", password: "fjqrt45e")
            print("🔑 Token: \(token)")

            // 3. Get current user
            let me = try await api.getCurrentUser()
            print("👤 User: \(me.full_name) (Role: \(me.role_name))")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}
