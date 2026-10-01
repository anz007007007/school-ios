import SwiftUI

struct ClubFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новый кружок"
            case .edit:
                return "Редактирование"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create:
                return "Добавить"
            case .edit:
                return "Сохранить"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let club: ClubDTO?
    let teachers: [ClubFilterTeacherDTO]
    let initialTeacherID: Int
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (ClubFormData) -> Void

    @State private var name: String
    @State private var description: String
    @State private var selectedWeekdayIDs: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var capacity: Int
    @State private var priceAmount: String
    @State private var paymentType: String
    @State private var teacherID: Int
    @State private var status: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        club: ClubDTO?,
        teachers: [ClubFilterTeacherDTO],
        initialTeacherID: Int,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (ClubFormData) -> Void
    ) {
        self.mode = mode
        self.club = club
        self.teachers = teachers
        self.initialTeacherID = initialTeacherID
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _name = State(initialValue: club?.name ?? "")
        _description = State(initialValue: club?.description ?? "")
        _selectedWeekdayIDs = State(initialValue: Set([club?.weekday ?? 1]))
        _startTime = State(initialValue: Self.dateFromTime(club?.start_time) ?? Date())
        _endTime = State(initialValue: Self.dateFromTime(club?.end_time) ?? Date().addingTimeInterval(3600))
        _capacity = State(initialValue: club?.capacity ?? 10)
        _priceAmount = State(initialValue: club?.price_amount ?? "0")
        _paymentType = State(initialValue: ClubsViewModel.normalizedPricePeriod(club?.paymentTypeValue) ?? "month")
        _teacherID = State(initialValue: initialTeacherID)
        _status = State(initialValue: club?.status ?? "active")
    }

    var body: some View {
        NavigationStack {
            Form {
                mainSection
                teacherSection
                paymentSection
                statusSection

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
            .appThemedForm()
            .navigationTitle(mode.title)
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
                            Text(mode.saveButtonTitle)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var mainSection: some View {
        Section("Основное") {
            TextField("Название", text: $name)

            TextField("Описание", text: $description, axis: .vertical)
                .lineLimit(3...8)

            DisclosureGroup("Дни недели: \(selectedWeekdayIDs.count)") {
                weekdayToggle(title: "Понедельник", id: 1)
                weekdayToggle(title: "Вторник", id: 2)
                weekdayToggle(title: "Среда", id: 3)
                weekdayToggle(title: "Четверг", id: 4)
                weekdayToggle(title: "Пятница", id: 5)
                weekdayToggle(title: "Суббота", id: 6)
                weekdayToggle(title: "Воскресенье", id: 7)
            }

            if mode == .edit && selectedWeekdayIDs.count > 1 {
                Text("При редактировании существующего кружка будет использован первый выбранный день. Несколько дней создаются только при добавлении нового кружка.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            DatePicker(
                "Начало",
                selection: $startTime,
                displayedComponents: [.hourAndMinute]
            )

            DatePicker(
                "Окончание",
                selection: $endTime,
                displayedComponents: [.hourAndMinute]
            )

            Stepper("Вместимость: \(capacity)", value: $capacity, in: 1...500)
        }
    }

    private var teacherSection: some View {
        Section("Преподаватель") {
            if teachers.isEmpty {
                Text("Список преподавателей не загружен.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Преподаватель", selection: $teacherID) {
                    Text("Выберите преподавателя").tag(0)

                    ForEach(teachers) { teacher in
                        Text(teacher.teacher_name).tag(teacher.id)
                    }
                }
            }
        }
    }

    private var paymentSection: some View {
        Section("Оплата") {
            Picker("Тип оплаты", selection: $paymentType) {
                ForEach(ClubsViewModel.pricePeriodOptions, id: \.value) { option in
                    Text(option.title).tag(option.value)
                }
            }

            TextField("Стоимость", text: $priceAmount)
                .keyboardType(.decimalPad)
                .disabled(paymentType == "free")
                .onChange(of: paymentType) {
                    if paymentType == "free" {
                        priceAmount = "0"
                    }
                }
        }
    }

    private var statusSection: some View {
        Section("Статус") {
            Picker("Статус", selection: $status) {
                Text("Активен").tag("active")
                Text("Черновик").tag("draft")
                Text("Архив").tag("archived")
            }
            .pickerStyle(.segmented)
        }
    }

    private func weekdayToggle(title: String, id: Int) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: {
                    selectedWeekdayIDs.contains(id)
                },
                set: { isSelected in
                    if isSelected {
                        selectedWeekdayIDs.insert(id)
                    } else {
                        selectedWeekdayIDs.remove(id)
                    }
                }
            )
        )
    }

    private func save() {
        validationMessage = nil

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPriceAmount = priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            validationMessage = "Введите название кружка"
            return
        }

        guard !selectedWeekdayIDs.isEmpty else {
            validationMessage = "Выберите хотя бы один день недели"
            return
        }

        guard teacherID != 0 else {
            validationMessage = "Выберите преподавателя"
            return
        }

        let formData = ClubFormData(
            name: cleanName,
            description: cleanDescription,
            weekdayIDs: Array(selectedWeekdayIDs).sorted(),
            startTime: Self.timeFormatter.string(from: startTime),
            endTime: Self.timeFormatter.string(from: endTime),
            capacity: capacity,
            priceAmount: paymentType == "free" ? "0" : (cleanPriceAmount.isEmpty ? "0" : cleanPriceAmount),
            paymentType: paymentType,
            teacherID: teacherID,
            status: status
        )

        onSave(formData)
        dismiss()
    }

    private static func dateFromTime(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return timeFormatter.date(from: value)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}