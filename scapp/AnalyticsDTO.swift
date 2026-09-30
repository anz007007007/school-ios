import Foundation

struct AnalyticsDashboardDTO: Decodable, Hashable {
    let overview: AnalyticsOverviewDTO?
    let students: AnalyticsStudentsDTO?
    let teachers: AnalyticsTeachersDTO?
    let parents: AnalyticsParentsDTO?
    let engagement: AnalyticsEngagementDTO?
    let finance: AnalyticsFinanceDTO?
    let health: AnalyticsHealthDTO?
    let communications: AnalyticsCommunicationDTO?
}

struct AnalyticsOverviewDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let role_distribution: [AnalyticsChartPointDTO]
    let class_distribution: [AnalyticsChartPointDTO]
    let app_platform_distribution: [AnalyticsChartPointDTO]
    let login_activity: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case role_distribution
        case class_distribution
        case app_platform_distribution
        case login_activity
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        role_distribution: [AnalyticsChartPointDTO] = [],
        class_distribution: [AnalyticsChartPointDTO] = [],
        app_platform_distribution: [AnalyticsChartPointDTO] = [],
        login_activity: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.role_distribution = role_distribution
        self.class_distribution = class_distribution
        self.app_platform_distribution = app_platform_distribution
        self.login_activity = login_activity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []
        role_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .role_distribution) ?? []
        class_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .class_distribution) ?? []
        app_platform_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .app_platform_distribution) ?? []
        login_activity = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .login_activity) ?? []
    }
}

struct AnalyticsStudentsDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let performance: [AnalyticsStudentPerformanceItemDTO]
    let class_distribution: [AnalyticsChartPointDTO]
    let attendance_distribution: [AnalyticsChartPointDTO]
    let performance_distribution: [AnalyticsChartPointDTO]
    let risk_distribution: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case summary
        case performance
        case items
        case class_distribution
        case attendance_distribution
        case performance_distribution
        case risk_distribution
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        performance: [AnalyticsStudentPerformanceItemDTO] = [],
        class_distribution: [AnalyticsChartPointDTO] = [],
        attendance_distribution: [AnalyticsChartPointDTO] = [],
        performance_distribution: [AnalyticsChartPointDTO] = [],
        risk_distribution: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.performance = performance
        self.class_distribution = class_distribution
        self.attendance_distribution = attendance_distribution
        self.performance_distribution = performance_distribution
        self.risk_distribution = risk_distribution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics)
            ?? container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .summary)
            ?? []

        performance = try container.decodeIfPresent([AnalyticsStudentPerformanceItemDTO].self, forKey: .performance)
            ?? container.decodeIfPresent([AnalyticsStudentPerformanceItemDTO].self, forKey: .items)
            ?? []

        class_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .class_distribution) ?? []
        attendance_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .attendance_distribution) ?? []
        performance_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .performance_distribution) ?? []
        risk_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .risk_distribution) ?? []
    }
}

struct AnalyticsTeachersDTO: Decodable, Hashable {
    let items: [AnalyticsTeacherItemDTO]
    let summary: [AnalyticsMetricDTO]

    enum CodingKeys: String, CodingKey {
        case items
        case summary
        case metrics
    }

    init(
        items: [AnalyticsTeacherItemDTO] = [],
        summary: [AnalyticsMetricDTO] = []
    ) {
        self.items = items
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        items = try container.decodeIfPresent([AnalyticsTeacherItemDTO].self, forKey: .items) ?? []
        summary = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .summary)
            ?? container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics)
            ?? []
    }
}

struct AnalyticsParentsDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let linked_children_distribution: [AnalyticsChartPointDTO]
    let activity: [AnalyticsChartPointDTO]
    let engagement_distribution: [AnalyticsChartPointDTO]
    let items: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case linked_children_distribution
        case activity
        case engagement_distribution
        case items
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        linked_children_distribution: [AnalyticsChartPointDTO] = [],
        activity: [AnalyticsChartPointDTO] = [],
        engagement_distribution: [AnalyticsChartPointDTO] = [],
        items: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.linked_children_distribution = linked_children_distribution
        self.activity = activity
        self.engagement_distribution = engagement_distribution
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []

        linked_children_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .linked_children_distribution)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .items)
            ?? []

        activity = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .activity)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .engagement_distribution)
            ?? []

        engagement_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .engagement_distribution) ?? []
        items = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .items) ?? []
    }
}

struct AnalyticsEngagementDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let daily_active_users: [AnalyticsChartPointDTO]
    let feature_usage: [AnalyticsChartPointDTO]
    let role_activity: [AnalyticsChartPointDTO]
    let active_users_by_role: [AnalyticsChartPointDTO]
    let inactive_users_by_role: [AnalyticsChartPointDTO]
    let platform_distribution: [AnalyticsChartPointDTO]
    let recent_logins: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case daily_active_users
        case feature_usage
        case role_activity
        case active_users_by_role
        case inactive_users_by_role
        case platform_distribution
        case recent_logins
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        daily_active_users: [AnalyticsChartPointDTO] = [],
        feature_usage: [AnalyticsChartPointDTO] = [],
        role_activity: [AnalyticsChartPointDTO] = [],
        active_users_by_role: [AnalyticsChartPointDTO] = [],
        inactive_users_by_role: [AnalyticsChartPointDTO] = [],
        platform_distribution: [AnalyticsChartPointDTO] = [],
        recent_logins: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.daily_active_users = daily_active_users
        self.feature_usage = feature_usage
        self.role_activity = role_activity
        self.active_users_by_role = active_users_by_role
        self.inactive_users_by_role = inactive_users_by_role
        self.platform_distribution = platform_distribution
        self.recent_logins = recent_logins
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []

        daily_active_users = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .daily_active_users)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .active_users_by_role)
            ?? []

        feature_usage = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .feature_usage)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .platform_distribution)
            ?? []

        role_activity = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .role_activity)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .inactive_users_by_role)
            ?? []

        active_users_by_role = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .active_users_by_role) ?? []
        inactive_users_by_role = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .inactive_users_by_role) ?? []
        platform_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .platform_distribution) ?? []
        recent_logins = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .recent_logins) ?? []
    }
}

struct AnalyticsFinanceDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let invoice_status_distribution: [AnalyticsChartPointDTO]
    let payment_method_distribution: [AnalyticsChartPointDTO]
    let monthly_payments: [AnalyticsChartPointDTO]
    let debtors: [AnalyticsDebtorDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case invoice_status_distribution
        case payment_method_distribution
        case monthly_payments
        case debtors
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        invoice_status_distribution: [AnalyticsChartPointDTO] = [],
        payment_method_distribution: [AnalyticsChartPointDTO] = [],
        monthly_payments: [AnalyticsChartPointDTO] = [],
        debtors: [AnalyticsDebtorDTO] = []
    ) {
        self.metrics = metrics
        self.invoice_status_distribution = invoice_status_distribution
        self.payment_method_distribution = payment_method_distribution
        self.monthly_payments = monthly_payments
        self.debtors = debtors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []
        invoice_status_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .invoice_status_distribution) ?? []
        payment_method_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .payment_method_distribution) ?? []
        monthly_payments = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .monthly_payments) ?? []
        debtors = try container.decodeIfPresent([AnalyticsDebtorDTO].self, forKey: .debtors) ?? []
    }
}

struct AnalyticsHealthDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let health_groups: [AnalyticsChartPointDTO]
    let allergy_distribution: [AnalyticsChartPointDTO]
    let medical_notes: [AnalyticsChartPointDTO]
    let risk_distribution: [AnalyticsChartPointDTO]
    let health_cards_by_class: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case health_groups
        case allergy_distribution
        case medical_notes
        case risk_distribution
        case health_cards_by_class
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        health_groups: [AnalyticsChartPointDTO] = [],
        allergy_distribution: [AnalyticsChartPointDTO] = [],
        medical_notes: [AnalyticsChartPointDTO] = [],
        risk_distribution: [AnalyticsChartPointDTO] = [],
        health_cards_by_class: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.health_groups = health_groups
        self.allergy_distribution = allergy_distribution
        self.medical_notes = medical_notes
        self.risk_distribution = risk_distribution
        self.health_cards_by_class = health_cards_by_class
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []

        health_groups = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .health_groups)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .risk_distribution)
            ?? []

        allergy_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .allergy_distribution) ?? []

        medical_notes = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .medical_notes)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .health_cards_by_class)
            ?? []

        risk_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .risk_distribution) ?? []
        health_cards_by_class = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .health_cards_by_class) ?? []
    }
}

struct AnalyticsCommunicationDTO: Decodable, Hashable {
    let metrics: [AnalyticsMetricDTO]
    let messages_by_day: [AnalyticsChartPointDTO]
    let announcements_by_day: [AnalyticsChartPointDTO]
    let role_distribution: [AnalyticsChartPointDTO]
    let message_activity_by_role: [AnalyticsChartPointDTO]
    let unread_by_role: [AnalyticsChartPointDTO]
    let notifications_by_type: [AnalyticsChartPointDTO]

    enum CodingKeys: String, CodingKey {
        case metrics
        case messages_by_day
        case announcements_by_day
        case role_distribution
        case message_activity_by_role
        case unread_by_role
        case notifications_by_type
    }

    init(
        metrics: [AnalyticsMetricDTO] = [],
        messages_by_day: [AnalyticsChartPointDTO] = [],
        announcements_by_day: [AnalyticsChartPointDTO] = [],
        role_distribution: [AnalyticsChartPointDTO] = [],
        message_activity_by_role: [AnalyticsChartPointDTO] = [],
        unread_by_role: [AnalyticsChartPointDTO] = [],
        notifications_by_type: [AnalyticsChartPointDTO] = []
    ) {
        self.metrics = metrics
        self.messages_by_day = messages_by_day
        self.announcements_by_day = announcements_by_day
        self.role_distribution = role_distribution
        self.message_activity_by_role = message_activity_by_role
        self.unread_by_role = unread_by_role
        self.notifications_by_type = notifications_by_type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metrics = try container.decodeIfPresent([AnalyticsMetricDTO].self, forKey: .metrics) ?? []

        messages_by_day = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .messages_by_day)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .message_activity_by_role)
            ?? []

        announcements_by_day = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .announcements_by_day)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .unread_by_role)
            ?? []

        role_distribution = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .role_distribution)
            ?? container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .notifications_by_type)
            ?? []

        message_activity_by_role = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .message_activity_by_role) ?? []
        unread_by_role = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .unread_by_role) ?? []
        notifications_by_type = try container.decodeIfPresent([AnalyticsChartPointDTO].self, forKey: .notifications_by_type) ?? []
    }
}

struct AnalyticsMetricDTO: Decodable, Identifiable, Hashable {
    let code: String?
    let title: String?
    let label: String?
    let value: AnalyticsFlexibleValue?
    let unit: String?
    let trend: AnalyticsFlexibleValue?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case code
        case title
        case label
        case name
        case value
        case unit
        case trend
        case description
    }

    var id: String {
        code ?? title ?? label ?? UUID().uuidString
    }

    var displayTitle: String {
        title ?? label ?? code ?? "Показатель"
    }

    var displayValue: String {
        value?.displayText ?? "—"
    }

    var displaySubtitle: String? {
        if let description, !description.isEmpty {
            return description
        }

        if let unit, !unit.isEmpty {
            return unit
        }

        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decodeIfPresent(String.self, forKey: .code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        value = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .value)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        trend = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .trend)
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

struct AnalyticsChartPointDTO: Decodable, Identifiable, Hashable {
    let label: String?
    let title: String?
    let name: String?
    let value: AnalyticsFlexibleValue?
    let count: Int?
    let percent: Double?

    enum CodingKeys: String, CodingKey {
        case label
        case title
        case name
        case role
        case status
        case type
        case platform
        case class_name
        case risk_level
        case value
        case count
        case total
        case percent
        case percentage
    }

    var id: String {
        "\(displayLabel)-\(displayValue)"
    }

    var displayLabel: String {
        label ?? title ?? name ?? "—"
    }

    var displayValue: String {
        if let value {
            return value.displayText
        }

        if let count {
            return "\(count)"
        }

        if let percent {
            return String(format: "%.1f%%", percent)
        }

        return "—"
    }

    var numericValue: Double {
        if let count {
            return Double(count)
        }

        if let percent {
            return percent
        }

        return value?.doubleValue ?? 0
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedLabel = try container.decodeIfPresent(String.self, forKey: .label)
        let decodedRole = try container.decodeIfPresent(String.self, forKey: .role)
        let decodedStatus = try container.decodeIfPresent(String.self, forKey: .status)
        let decodedType = try container.decodeIfPresent(String.self, forKey: .type)
        let decodedPlatform = try container.decodeIfPresent(String.self, forKey: .platform)
        let decodedClassName = try container.decodeIfPresent(String.self, forKey: .class_name)
        let decodedRiskLevel = try container.decodeIfPresent(String.self, forKey: .risk_level)

        if let decodedLabel {
            label = decodedLabel
        } else if let decodedRole {
            label = decodedRole
        } else if let decodedStatus {
            label = decodedStatus
        } else if let decodedType {
            label = decodedType
        } else if let decodedPlatform {
            label = decodedPlatform
        } else if let decodedClassName {
            label = decodedClassName
        } else {
            label = decodedRiskLevel
        }

        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        let decodedValue = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .value)
        let decodedTotalValue = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .total)

        if let decodedValue {
            value = decodedValue
        } else {
            value = decodedTotalValue
        }

        let decodedCount = try container.decodeFlexibleInt(forKey: .count)
        let decodedTotalCount = try container.decodeFlexibleInt(forKey: .total)

        if let decodedCount {
            count = decodedCount
        } else {
            count = decodedTotalCount
        }

        let decodedPercent = try container.decodeFlexibleDouble(forKey: .percent)
        let decodedPercentage = try container.decodeFlexibleDouble(forKey: .percentage)

        if let decodedPercent {
            percent = decodedPercent
        } else {
            percent = decodedPercentage
        }
    }
}

struct AnalyticsStudentPerformanceItemDTO: Decodable, Identifiable, Hashable {
    let student_id: Int?
    let student_name: String?
    let full_name: String?
    let class_name: String?
    let average_grade: Double?
    let grades_count: Int?
    let attendance_percent: Double?
    let missed_lessons: Int?

    let excellent_count: Int?
    let good_count: Int?
    let satisfactory_count: Int?
    let bad_count: Int?
    let attendance_total: Int?
    let absence_count: Int?
    let late_count: Int?
    let risk_level: String?

    enum CodingKeys: String, CodingKey {
        case student_id
        case id
        case student_name
        case full_name
        case name
        case class_name
        case average_grade
        case grades_count
        case attendance_percent
        case missed_lessons
        case excellent_count
        case good_count
        case satisfactory_count
        case bad_count
        case attendance_total
        case absence_count
        case late_count
        case risk_level
    }

    var id: Int {
        student_id ?? 0
    }

    var displayName: String {
        student_name ?? full_name ?? "Ученик"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        student_id = try container.decodeFlexibleInt(forKey: .student_id)
            ?? container.decodeFlexibleInt(forKey: .id)

        student_name = try container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .name)

        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name)
        average_grade = try container.decodeFlexibleDouble(forKey: .average_grade)
        grades_count = try container.decodeFlexibleInt(forKey: .grades_count)
        attendance_percent = try container.decodeFlexibleDouble(forKey: .attendance_percent)
        missed_lessons = try container.decodeFlexibleInt(forKey: .missed_lessons)
        excellent_count = try container.decodeFlexibleInt(forKey: .excellent_count)
        good_count = try container.decodeFlexibleInt(forKey: .good_count)
        satisfactory_count = try container.decodeFlexibleInt(forKey: .satisfactory_count)
        bad_count = try container.decodeFlexibleInt(forKey: .bad_count)
        attendance_total = try container.decodeFlexibleInt(forKey: .attendance_total)
        absence_count = try container.decodeFlexibleInt(forKey: .absence_count)
        late_count = try container.decodeFlexibleInt(forKey: .late_count)
        risk_level = try container.decodeIfPresent(String.self, forKey: .risk_level)
    }
}

struct AnalyticsTeacherItemDTO: Decodable, Identifiable, Hashable {
    let teacher_id: Int?
    let teacher_name: String?
    let full_name: String?
    let subjects_count: Int?
    let classes_count: Int?
    let grades_count: Int?
    let homework_count: Int?
    let attendance_count: Int?
    let average_grade: Double?

    enum CodingKeys: String, CodingKey {
        case teacher_id
        case id
        case teacher_name
        case full_name
        case name
        case subjects_count
        case classes_count
        case grades_count
        case homework_count
        case attendance_count
        case average_grade
    }

    var id: Int {
        teacher_id ?? 0
    }

    var displayName: String {
        teacher_name ?? full_name ?? "Учитель"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        teacher_id = try container.decodeFlexibleInt(forKey: .teacher_id)
            ?? container.decodeFlexibleInt(forKey: .id)

        teacher_name = try container.decodeIfPresent(String.self, forKey: .teacher_name)
            ?? container.decodeIfPresent(String.self, forKey: .name)

        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        subjects_count = try container.decodeFlexibleInt(forKey: .subjects_count)
        classes_count = try container.decodeFlexibleInt(forKey: .classes_count)
        grades_count = try container.decodeFlexibleInt(forKey: .grades_count)
        homework_count = try container.decodeFlexibleInt(forKey: .homework_count)
        attendance_count = try container.decodeFlexibleInt(forKey: .attendance_count)
        average_grade = try container.decodeFlexibleDouble(forKey: .average_grade)
    }
}

struct AnalyticsDebtorDTO: Decodable, Identifiable, Hashable {
    let student_id: Int?
    let student_name: String?
    let full_name: String?
    let class_name: String?
    let amount: AnalyticsFlexibleValue?
    let debt_amount: AnalyticsFlexibleValue?
    let overdue_amount: AnalyticsFlexibleValue?
    let invoices_count: Int?

    enum CodingKeys: String, CodingKey {
        case student_id
        case id
        case student_name
        case full_name
        case name
        case class_name
        case amount
        case debt_amount
        case overdue_amount
        case invoices_count
    }

    var id: Int {
        student_id ?? 0
    }

    var displayName: String {
        student_name ?? full_name ?? "Ученик"
    }

    var displayDebt: String {
        debt_amount?.displayText ?? amount?.displayText ?? "—"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        student_id = try container.decodeFlexibleInt(forKey: .student_id)
            ?? container.decodeFlexibleInt(forKey: .id)

        student_name = try container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .name)

        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name)
        amount = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .amount)
        debt_amount = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .debt_amount)
        overdue_amount = try container.decodeIfPresent(AnalyticsFlexibleValue.self, forKey: .overdue_amount)
        invoices_count = try container.decodeFlexibleInt(forKey: .invoices_count)
    }
}

enum AnalyticsFlexibleValue: Decodable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case unknown

    var displayText: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return "\(value)"
        case .double(let value):
            if value.rounded() == value {
                return "\(Int(value))"
            }

            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "Да" : "Нет"
        case .unknown:
            return "—"
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        case .string(let value):
            return Double(value.replacingOccurrences(of: ",", with: "."))
        case .bool(let value):
            return value ? 1 : 0
        case .unknown:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        self = .unknown
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }

        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }

        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue.replacingOccurrences(of: ",", with: "."))
        }

        return nil
    }
}