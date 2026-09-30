import Foundation

struct HealthFiltersResponseDTO: Codable {
    let students: [HealthStudentFilterDTO]
}

struct HealthStudentFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_name: String
    let class_name: String?
}

struct HealthOverviewResponseDTO: Codable, Hashable {
    let total_cards: Int?
    let allergies_count: Int?
    let chronic_diseases_count: Int?
    let medical_notes_count: Int?
}

struct HealthCardsListResponseDTO: Codable {
    let items: [HealthCardDTO]
}

struct HealthCardDTO: Codable, Identifiable, Hashable {
    let student_id: Int
    let student_name: String
    let class_name: String?

    let blood_type: String?
    let health_group: String?
    let physical_activity_group: String?

    let allergies: String?
    let contraindications: String?
    let chronic_diseases: String?

    let food_recommendations: String?
    let health_recommendations: String?
    let medication_notes: String?
    let daily_regimen: String?

    let emergency_contact: String?
    let doctor_contacts: String?

    let risk_level: String?
    let physical_restrictions: String?
    let vaccination_notes: String?
    let vaccinations: String?
    let last_checkup_at: String?
    let notes: String?

    // Старое поле, если backend ещё где-то его отдаёт.
    let medical_notes: String?

    var id: Int {
        student_id
    }

    var effectiveVaccinationNotes: String? {
        if let vaccination_notes, !vaccination_notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return vaccination_notes
        }

        return vaccinations
    }

    var effectiveNotes: String? {
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }

        return medical_notes
    }

    var hasAllergies: Bool {
        !(allergies ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasChronicDiseases: Bool {
        !(chronic_diseases ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasImportantNotes: Bool {
        hasAllergies
        || hasChronicDiseases
        || !(contraindications ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !(physical_restrictions ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || risk_level == "medium"
        || risk_level == "high"
        || risk_level == "critical"
    }

    var riskTitle: String {
        switch risk_level {
        case "low":
            return "Низкий"
        case "medium":
            return "Средний"
        case "high":
            return "Высокий"
        case "critical":
            return "Критический"
        case let value?:
            return value
        case nil:
            return "Не указан"
        }
    }
}

struct HealthCardFormData: Hashable {
    let studentID: Int

    let bloodType: String
    let healthGroup: String
    let physicalActivityGroup: String

    let allergies: String
    let contraindications: String
    let chronicDiseases: String

    let foodRecommendations: String
    let healthRecommendations: String
    let medicationNotes: String
    let dailyRegimen: String

    let emergencyContact: String
    let doctorContacts: String

    let riskLevel: String
    let physicalRestrictions: String
    let vaccinationNotes: String
    let lastCheckupAt: String
    let notes: String
}

struct HealthCardSaveRequestDTO: Codable {
    let student_id: Int

    let blood_type: String?
    let health_group: String?
    let physical_activity_group: String?

    let allergies: String?
    let contraindications: String?
    let chronic_diseases: String?

    let food_recommendations: String?
    let health_recommendations: String?
    let medication_notes: String?
    let daily_regimen: String?

    let emergency_contact: String?
    let doctor_contacts: String?

    let risk_level: String?
    let physical_restrictions: String?
    let vaccination_notes: String?
    let last_checkup_at: String?
    let notes: String?
}

struct HealthCardSaveResponseDTO: Codable {
    let status: String?
    let message: String?
}