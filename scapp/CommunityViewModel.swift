import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published var dashboard: CommunityDashboardDTO?
    @Published var parentAds: [CommunityParentAdDTO] = []
    @Published var schoolNeeds: [CommunitySchoolNeedDTO] = []

    @Published var myParentAd: CommunityParentAdDTO?
    @Published var adminPromos: [CommunityAdminPromoDTO] = []

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isSendingContribution = false

    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadDashboard(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                CommunityDashboardDTO.self,
                api: api,
                path: "/api/v1/community/dashboard",
                method: "GET",
                logPrefix: "COMMUNITY DASHBOARD"
            )

            dashboard = response
            parentAds = response.parent_ads.filter { $0.status == "active" }
            schoolNeeds = response.school_needs.filter { ($0.status ?? "active") == "active" }
        } catch {
            errorMessage = "Не удалось загрузить объявления и потребности: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func sendContribution(
        api: SchoolAPI,
        needID: Int,
        amount: Double?,
        comment: String?
    ) async {
        isSendingContribution = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/needs/\(needID)/contributions",
                method: "POST",
                body: CommunityContributionRequestDTO(
                    amount: amount,
                    comment: comment
                ).body,
                logPrefix: "COMMUNITY NEED CONTRIBUTION"
            )

            successMessage = "Спасибо! Ваш вклад отмечен."
            await loadDashboard(api: api)
        } catch {
            errorMessage = "Не удалось отправить вклад: \(error.localizedDescription)"
        }

        isSendingContribution = false
    }

    func loadMyParentAd(api: SchoolAPI) async {
        errorMessage = nil

        do {
            let data = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/parent-ads/my",
                method: "GET",
                logPrefix: "COMMUNITY MY PARENT AD"
            )

            // null означает, что у родителя пока нет объявления — это не ошибка.
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if text.isEmpty || text == "null" {
                myParentAd = nil
                return
            }

            myParentAd = try JSONDecoder().decode(CommunityParentAdDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить ваше объявление: \(error.localizedDescription)"
        }
    }

    func saveMyParentAd(
        api: SchoolAPI,
        formData: CommunityParentAdFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let saved = try await APIRequestService.shared.decode(
                CommunityParentAdDTO.self,
                api: api,
                path: "/api/v1/community/parent-ads/my",
                method: "POST",
                body: formData.body,
                logPrefix: "COMMUNITY SAVE MY PARENT AD"
            )

            myParentAd = saved
            successMessage = "Ваше объявление сохранено"

            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить объявление: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func loadAdminPromos(api: SchoolAPI) async {
        errorMessage = nil

        do {
            // Сервер отдаёт голый список (response_model=list[PromoCampaignResponse]).
            let response = try await APIRequestService.shared.decode(
                [CommunityAdminPromoDTO].self,
                api: api,
                path: "/api/v1/community/admin/promos",
                method: "GET",
                logPrefix: "COMMUNITY ADMIN PROMOS"
            )

            adminPromos = response.sorted {
                ($0.updated_at ?? $0.created_at ?? "") > ($1.updated_at ?? $1.created_at ?? "")
            }
        } catch {
            errorMessage = "Не удалось загрузить промо: \(error.localizedDescription)"
        }
    }

    func createAdminPromo(
        api: SchoolAPI,
        formData: CommunityPromoFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos",
                method: "POST",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN PROMO CREATE"
            )

            successMessage = "Промо создано"
            await loadAdminPromos(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateAdminPromo(
        api: SchoolAPI,
        promoID: Int,
        formData: CommunityPromoFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos/\(promoID)",
                method: "PUT",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN PROMO UPDATE"
            )

            successMessage = "Промо обновлено"
            await loadAdminPromos(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteAdminPromo(
        api: SchoolAPI,
        promoID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos/\(promoID)",
                method: "DELETE",
                logPrefix: "COMMUNITY ADMIN PROMO DELETE"
            )

            adminPromos.removeAll { $0.id == promoID }
            successMessage = "Промо удалено"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createAdminNeed(
        api: SchoolAPI,
        formData: CommunityNeedFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs",
                method: "POST",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN NEED CREATE"
            )

            successMessage = "Потребность школы создана"
            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateAdminNeed(
        api: SchoolAPI,
        needID: Int,
        formData: CommunityNeedFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs/\(needID)",
                method: "PUT",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN NEED UPDATE"
            )

            successMessage = "Потребность школы обновлена"
            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteAdminNeed(
        api: SchoolAPI,
        needID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs/\(needID)",
                method: "DELETE",
                logPrefix: "COMMUNITY ADMIN NEED DELETE"
            )

            schoolNeeds.removeAll { $0.id == needID }
            successMessage = "Потребность школы удалена"

            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }
}

@MainActor
final class CommunityPromoViewModel: ObservableObject {
    @Published var promoToShow: CommunityPromoDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var checkedUserID: Int?

    func checkPromoForCurrentUser(
        api: SchoolAPI,
        userID: Int?
    ) async {
        guard let userID else {
            return
        }

        guard checkedUserID != userID else {
            return
        }

        checkedUserID = userID
        await checkPromo(api: api)
    }

    func forceCheckPromo(api: SchoolAPI) async {
        await checkPromo(api: api)
    }

    func resetCheckedUser() {
        checkedUserID = nil
        promoToShow = nil
        errorMessage = nil
    }

    private func checkPromo(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/dashboard",
                method: "GET",
                logPrefix: "COMMUNITY PROMO RAW DASHBOARD"
            )

            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("COMMUNITY PROMO RAW BODY:", responseText)

            let response = try JSONDecoder().decode(CommunityDashboardDTO.self, from: data)

            print("COMMUNITY PROMO COUNT:", response.promos.count)

            if let firstPromo = response.promos.first {
                print("COMMUNITY PROMO FOUND:", firstPromo.id, firstPromo.title)
                promoToShow = firstPromo
            } else {
                print("COMMUNITY PROMO EMPTY")
                promoToShow = nil
            }
        } catch {
            errorMessage = "Не удалось загрузить промо: \(error.localizedDescription)"
            print("COMMUNITY PROMO ERROR:", error.localizedDescription)
        }

        isLoading = false
    }

    func markImpression(api: SchoolAPI, promo: CommunityPromoDTO) async {
        guard promo.id > 0 else {
            print("COMMUNITY PROMO IMPRESSION SKIPPED: BAD PROMO ID")
            return
        }

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/promos/\(promo.id)/impression",
                method: "POST",
                body: [:],
                logPrefix: "COMMUNITY PROMO IMPRESSION"
            )
        } catch {
            errorMessage = "Не удалось зафиксировать показ промо: \(error.localizedDescription)"
            print("COMMUNITY PROMO IMPRESSION ERROR:", error.localizedDescription)
        }
    }
}