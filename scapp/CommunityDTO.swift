import Foundation

enum CommunityConstants {
    static let baseURL = "https://sc.it-status.ru"

    static func resolveImageUrl(_ url: String?) -> URL? {
        guard let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return URL(string: raw)
        }

        return URL(string: baseURL + raw)
    }
}

struct CommunityDashboardDTO: Decodable {
    let promos: [CommunityPromoDTO]
    let parent_ads: [CommunityParentAdDTO]
    let school_needs: [CommunitySchoolNeedDTO]

    enum CodingKeys: String, CodingKey {
        case promos
        case parent_ads
        case parentAds
        case school_needs
        case schoolNeeds
    }

    init(
        promos: [CommunityPromoDTO],
        parent_ads: [CommunityParentAdDTO],
        school_needs: [CommunitySchoolNeedDTO]
    ) {
        self.promos = promos
        self.parent_ads = parent_ads
        self.school_needs = school_needs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        promos = (try? container.decodeIfPresent([CommunityPromoDTO].self, forKey: .promos)) ?? []

        parent_ads = (try? container.decodeIfPresent([CommunityParentAdDTO].self, forKey: .parent_ads))
            ?? (try? container.decodeIfPresent([CommunityParentAdDTO].self, forKey: .parentAds))
            ?? []

        school_needs = (try? container.decodeIfPresent([CommunitySchoolNeedDTO].self, forKey: .school_needs))
            ?? (try? container.decodeIfPresent([CommunitySchoolNeedDTO].self, forKey: .schoolNeeds))
            ?? []
    }
}

struct CommunityPromoDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let body: String
    let image_url: String?
    let impressions_limit: Int
    let impressions_count: Int
    let status: String?
    let starts_at: String?
    let ends_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campaign_id
        case promo_id
        case title
        case body
        case text
        case description
        case image_url
        case image
        case impressions_limit
        case impressions_count
        case user_impressions_count
        case status
        case starts_at
        case ends_at
    }

    init(
        id: Int,
        title: String,
        body: String,
        image_url: String?,
        impressions_limit: Int,
        impressions_count: Int,
        status: String?,
        starts_at: String?,
        ends_at: String?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.image_url = image_url
        self.impressions_limit = impressions_limit
        self.impressions_count = impressions_count
        self.status = status
        self.starts_at = starts_at
        self.ends_at = ends_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id)
            ?? container.decodeFlexibleInt(forKey: .campaign_id)
            ?? container.decodeFlexibleInt(forKey: .promo_id)
            ?? 0

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Объявление"

        body = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""

        image_url = try container.decodeIfPresent(String.self, forKey: .image_url)
            ?? container.decodeIfPresent(String.self, forKey: .image)

        impressions_limit = try container.decodeFlexibleInt(forKey: .impressions_limit) ?? 1

        impressions_count = try container.decodeFlexibleInt(forKey: .impressions_count)
            ?? container.decodeFlexibleInt(forKey: .user_impressions_count)
            ?? 0

        status = try container.decodeIfPresent(String.self, forKey: .status)
        starts_at = try container.decodeIfPresent(String.self, forKey: .starts_at)
        ends_at = try container.decodeIfPresent(String.self, forKey: .ends_at)
    }

    var imageURL: URL? {
        CommunityConstants.resolveImageUrl(image_url)
    }

    var impressionText: String {
        "Показ \(impressions_count + 1) из \(impressions_limit)"
    }
}

struct CommunityParentAdDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let parent_user_id: Int
    let parent_name: String
    let title: String
    let short_description: String
    let description: String
    let icon_url: String?
    let image_url: String?
    let contact_text: String?
    let status: String
    let created_at: String?
    let updated_at: String?

    var thumbnailURL: URL? {
        CommunityConstants.resolveImageUrl(icon_url ?? image_url)
    }

    var fullImageURL: URL? {
        CommunityConstants.resolveImageUrl(image_url ?? icon_url)
    }
}

struct CommunitySchoolNeedDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let description: String
    let image_url: String?
    let need_type: String
    let goal_amount: Double?
    let collected_amount: Double?
    let goal_text: String?
    let progress_percent: Double?
    let contributions_count: Int?
    let status: String?
    let priority: Int?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case image_url
        case image
        case need_type
        case goal_amount
        case collected_amount
        case goal_text
        case progress_percent
        case contributions_count
        case status
        case priority
        case created_at
        case updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        title = try container.decodeFlexibleString(forKey: .title) ?? "Потребность школы"
        description = try container.decodeFlexibleString(forKey: .description) ?? ""

        image_url = try container.decodeFlexibleString(forKey: .image_url)
            ?? container.decodeFlexibleString(forKey: .image)

        need_type = try container.decodeFlexibleString(forKey: .need_type) ?? "other"

        goal_amount = try container.decodeFlexibleDouble(forKey: .goal_amount)
        collected_amount = try container.decodeFlexibleDouble(forKey: .collected_amount)
        progress_percent = try container.decodeFlexibleDouble(forKey: .progress_percent)

        goal_text = try container.decodeFlexibleString(forKey: .goal_text)
        contributions_count = try container.decodeFlexibleInt(forKey: .contributions_count)
        status = try container.decodeFlexibleString(forKey: .status)
        priority = try container.decodeFlexibleInt(forKey: .priority)
        created_at = try container.decodeFlexibleString(forKey: .created_at)
        updated_at = try container.decodeFlexibleString(forKey: .updated_at)
    }

    var imageURL: URL? {
        CommunityConstants.resolveImageUrl(image_url)
    }

    var typeTitle: String {
        switch need_type {
        case "money":
            return "Денежный сбор"
        case "items":
            return "Вещи / материалы"
        case "volunteer":
            return "Волонтёрская помощь"
        case "other":
            return "Другое"
        default:
            return need_type
        }
    }

    var progressValue: Double? {
        guard let progress_percent else {
            return nil
        }

        return max(0, min(progress_percent / 100.0, 1.0))
    }

    var collectedText: String {
        let collected = collected_amount ?? 0

        if let goal = goal_amount {
            return "\(Self.amountText(collected)) из \(Self.amountText(goal))"
        }

        return Self.amountText(collected)
    }

    private static func amountText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.2f", value)
    }
}

struct CommunityContributionRequestDTO {
    let amount: Double?
    let comment: String?

    var body: [String: Any] {
        [
            "amount": amount as Any,
            "comment": comment as Any
        ]
    }
}

struct CommunityAdminPromoDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let body: String
    let image_url: String?
    let target_roles: [String]
    let impressions_limit: Int
    let starts_at: String?
    let ends_at: String?
    let status: String
    let published_at: String?
    let created_at: String?
    let updated_at: String?

    var imageURL: URL? {
        CommunityConstants.resolveImageUrl(image_url)
    }

    var targetRolesText: String {
        target_roles.map { CommunityRole.title($0) }.joined(separator: ", ")
    }
}

struct CommunityImageUploadResponseDTO: Decodable {
    let url: String
}

enum CommunityPromoStatus {
    static func title(_ code: String) -> String {
        switch code {
        case "published":
            return "опубликовано"
        case "draft":
            return "черновик"
        case "archived":
            return "в архиве"
        default:
            return "неизвестен"
        }
    }
}

enum CommunityRole {
    static let admin = "admin"
    static let manager = "manager"
    static let teacher = "teacher"
    static let parent = "parent"
    static let student = "student"

    static let promoTargetRoles = [
        parent,
        teacher,
        student
    ]

    static func title(_ code: String) -> String {
        switch code {
        case admin:
            return "Администраторы"
        case manager:
            return "Менеджеры"
        case teacher:
            return "Учителя"
        case parent:
            return "Родители"
        case student:
            return "Ученики"
        default:
            return "Другие"
        }
    }
}

struct CommunityParentAdFormData: Hashable {
    var title = ""
    var shortDescription = ""
    var description = ""
    var iconURL = ""
    var imageURL = ""
    var contactText = ""
    var status = "active"

    init() {}

    init(ad: CommunityParentAdDTO?) {
        guard let ad else {
            return
        }

        title = ad.title
        shortDescription = ad.short_description
        description = ad.description
        iconURL = ad.icon_url ?? ""
        imageURL = ad.image_url ?? ""
        contactText = ad.contact_text ?? ""
        status = ad.status
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !shortDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: [String: Any] {
        [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "short_description": shortDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "icon_url": cleanOptional(iconURL) as Any,
            "image_url": cleanOptional(imageURL) as Any,
            "contact_text": cleanOptional(contactText) as Any,
            "status": status
        ]
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}

struct CommunityPromoFormData: Hashable {
    var title = ""
    var body = ""
    var imageURL = ""
    var targetRoles = Set<String>([CommunityRole.parent])
    var impressionsLimit = 3
    var startsAt = ""
    var endsAt = ""
    var status = "published"

    init() {}

    init(promo: CommunityAdminPromoDTO?) {
        guard let promo else {
            return
        }

        title = promo.title
        body = promo.body
        imageURL = promo.image_url ?? ""
        targetRoles = Set(promo.target_roles)
        impressionsLimit = promo.impressions_limit
        startsAt = promo.starts_at ?? ""
        endsAt = promo.ends_at ?? ""
        status = promo.status
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !targetRoles.isEmpty
        && impressionsLimit > 0
    }

    var bodyDictionary: [String: Any] {
        [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "image_url": cleanOptional(imageURL) as Any,
            "target_roles": Array(targetRoles).sorted(),
            "impressions_limit": impressionsLimit,
            "starts_at": cleanOptional(startsAt) as Any,
            "ends_at": cleanOptional(endsAt) as Any,
            "status": status
        ]
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}

struct CommunityNeedFormData: Hashable {
    var title = ""
    var description = ""
    var imageURL = ""
    var needType = "items"
    var goalAmount = ""
    var collectedAmount = "0"
    var goalText = ""
    var status = "active"
    var priority = 100

    init() {}

    init(need: CommunitySchoolNeedDTO?) {
        guard let need else {
            return
        }

        title = need.title
        description = need.description
        imageURL = need.image_url ?? ""
        needType = need.need_type
        goalAmount = need.goal_amount.map { Self.amountText($0) } ?? ""
        collectedAmount = Self.amountText(need.collected_amount ?? 0)
        goalText = need.goal_text ?? ""
        status = need.status ?? "active"
        priority = need.priority ?? 100
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !needType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bodyDictionary: [String: Any] {
        [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "image_url": cleanOptional(imageURL) as Any,
            "need_type": needType,
            "goal_amount": parsedDouble(goalAmount) as Any,
            "collected_amount": parsedDouble(collectedAmount) ?? 0,
            "goal_text": cleanOptional(goalText) as Any,
            "status": status,
            "priority": priority
        ]
    }

    private func parsedDouble(_ value: String) -> Double? {
        let clean = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !clean.isEmpty else {
            return nil
        }

        return Double(clean)
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private static func amountText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.2f", value)
    }
}

enum CommunityNeedTypes {
    static let money = "money"
    static let items = "items"
    static let volunteer = "volunteer"
    static let other = "other"

    static let all = [
        money,
        items,
        volunteer,
        other
    ]

    static func title(_ type: String) -> String {
        switch type {
        case money:
            return "Деньги"
        case items:
            return "Вещи / материалы"
        case volunteer:
            return "Помощь руками"
        case other:
            return "Другое"
        default:
            return type
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let clean = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : stringValue
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return "\(intValue)"
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            if doubleValue.rounded() == doubleValue {
                return "\(Int(doubleValue))"
            }

            return "\(doubleValue)"
        }

        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue ? "true" : "false"
        }

        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let clean = stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")

            if clean.isEmpty {
                return nil
            }

            if let intValue = Int(clean) {
                return intValue
            }

            if let doubleValue = Double(clean) {
                return Int(doubleValue)
            }
        }

        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let clean = stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")

            if clean.isEmpty {
                return nil
            }

            return Double(clean)
        }

        return nil
    }
}