import SwiftUI

struct HealthCardFormView: View {
    @Environment(\.dismiss) private var dismiss

    let card: HealthCardDTO
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (HealthCardFormData) -> Void

    @State private var bloodType: String
    @State private var healthGroup: String
    @State private var physicalActivityGroup: String

    @State private var allergies: String
    @State private var contraindications: String
    @State private var chronicDiseases: String

    @State private var foodRecommendations: String
    @State private var healthRecommendations: String
    @State private var medicationNotes: String
    @State private var dailyRegimen: String

    @State private var emergencyContact: String
    @State private var doctorContacts: String

    @State private var riskLevel: String
    @State private var validationMessage: String?
    @State private var physicalRestrictions: String
    @State private var vaccinationNotes: String
    @State private var lastCheckupAt: String
    @State private var notes: String

    init(
        card: HealthCardDTO,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (HealthCardFormData) -> Void
    ) {
        self.card = card
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _bloodType = State(initialValue: card.blood_type ?? "")
        _healthGroup = State(initialValue: card.health_group ?? "")
        _physicalActivityGroup = State(initialValue: card.physical_activity_group ?? "")

        _allergies = State(initialValue: card.allergies ?? "")
        _contraindications = State(initialValue: card.contraindications ?? "")
        _chronicDiseases = State(initialValue: card.chronic_diseases ?? "")

        _foodRecommendations = State(initialValue: card.food_recommendations ?? "")
        _healthRecommendations = State(initialValue: card.health_recommendations ?? "")
        _medicationNotes = State(initialValue: card.medication_notes ?? "")
        _dailyRegimen = State(initialValue: card.daily_regimen ?? "")

        _emergencyContact = State(initialValue: card.emergency_contact ?? "")
        _doctorContacts = State(initialValue: card.doctor_contacts ?? "")

        _riskLevel = State(initialValue: Self.normalizedRiskLevel(card.risk_level))
        _physicalRestrictions = State(initialValue: card.physical_restrictions ?? "")
        _vaccinationNotes = State(initialValue: card.effectiveVaccinationNotes ?? "")
        _lastCheckupAt = State(initialValue: card.last_checkup_at ?? "")
        _notes = State(initialValue: card.effectiveNotes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ученик") {
                    LabeledContent("ФИО", value: card.student_name)

                    if let className = card.class_name, !className.isEmpty {
                        LabeledContent("Класс", value: className)
                    }
                }

                Section("Основное") {
                    Picker("Группа крови", selection: $bloodType) {
                        Text("Не указана").tag("")
                        Text("O(I)+").tag("O(I)+")
                        Text("O(I)-").tag("O(I)-")
                        Text("A(II)+").tag("A(II)+")
                        Text("A(II)-").tag("A(II)-")
                        Text("B(III)+").tag("B(III)+")
                        Text("B(III)-").tag("B(III)-")
                        Text("AB(IV)+").tag("AB(IV)+")
                        Text("AB(IV)-").tag("AB(IV)-")
                        Text("A+").tag("A+")
                        Text("A-").tag("A-")
                        Text("B+").tag("B+")
                        Text("B-").tag("B-")
                        Text("AB+").tag("AB+")
                        Text("AB-").tag("AB-")
                    }

                    TextField("Группа здоровья", text: $healthGroup)
                    TextField("Группа физической активности", text: $physicalActivityGroup)

                    Picker("Уровень риска", selection: $riskLevel) {
                        Text("Низкий").tag("low")
                        Text("Средний").tag("medium")
                        Text("Высокий").tag("high")
                    }
                }

                Section("Аллергии") {
                    TextEditor(text: $allergies)
                        .frame(minHeight: 90)
                }

                Section("Хронические заболевания") {
                    TextEditor(text: $chronicDiseases)
                        .frame(minHeight: 90)
                }

                Section("Противопоказания") {
                    TextEditor(text: $contraindications)
                        .frame(minHeight: 90)
                }

                Section("Физические ограничения") {
                    TextEditor(text: $physicalRestrictions)
                        .frame(minHeight: 90)
                }

                Section("Питание") {
                    TextEditor(text: $foodRecommendations)
                        .frame(minHeight: 90)
                }

                Section("Рекомендации по здоровью") {
                    TextEditor(text: $healthRecommendations)
                        .frame(minHeight: 90)
                }

                Section("Лекарства / медикаменты") {
                    TextEditor(text: $medicationNotes)
                        .frame(minHeight: 90)
                }

                Section("Режим дня") {
                    TextEditor(text: $dailyRegimen)
                        .frame(minHeight: 90)
                }

                Section("Прививки") {
                    TextEditor(text: $vaccinationNotes)
                        .frame(minHeight: 90)
                }

                Section("Контакты") {
                    TextField("Экстренный контакт", text: $emergencyContact)
                    TextField("Контакты врача", text: $doctorContacts)
                }

                Section("Последний осмотр") {
                    TextField("Дата: ДД.ММ.ГГГГ", text: $lastCheckupAt)
                        .textInputAutocapitalization(.never)

                    Text("Если дата неизвестна — оставьте поле пустым.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Заметки") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка сохранения", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Медкарта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    /// Сервер принимает только low | medium | high (schemas/health.py).
    private static func normalizedRiskLevel(_ value: String?) -> String {
        switch value {
        case "medium":
            return "medium"
        case "high", "critical":
            return "high"
        default:
            return "low"
        }
    }

    /// Дата осмотра для сервера в формате ГГГГ-ММ-ДД; nil — дата введена неверно.
    private static func normalizedCheckupDate(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return ""
        }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "yyyy-MM-dd"

        for format in ["yyyy-MM-dd", "dd.MM.yyyy", "d.M.yyyy"] {
            let input = DateFormatter()
            input.locale = Locale(identifier: "en_US_POSIX")
            input.dateFormat = format
            input.isLenient = false

            if let date = input.date(from: clean) {
                return output.string(from: date)
            }
        }

        return nil
    }

    private func save() {
        validationMessage = nil

        guard let checkupDate = Self.normalizedCheckupDate(lastCheckupAt) else {
            validationMessage = "Дата осмотра указана неверно. Введите её в формате ДД.ММ.ГГГГ или оставьте поле пустым."
            return
        }

        let formData = HealthCardFormData(
            studentID: card.student_id,
            bloodType: bloodType,
            healthGroup: healthGroup,
            physicalActivityGroup: physicalActivityGroup,
            allergies: allergies,
            contraindications: contraindications,
            chronicDiseases: chronicDiseases,
            foodRecommendations: foodRecommendations,
            healthRecommendations: healthRecommendations,
            medicationNotes: medicationNotes,
            dailyRegimen: dailyRegimen,
            emergencyContact: emergencyContact,
            doctorContacts: doctorContacts,
            riskLevel: riskLevel,
            physicalRestrictions: physicalRestrictions,
            vaccinationNotes: vaccinationNotes,
            lastCheckupAt: checkupDate,
            notes: notes
        )

        onSave(formData)
    }
}