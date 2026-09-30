import SwiftUI

struct EventFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новое событие"
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
    let event: EventTimelineDTO?
    let eventTypes: [String]
    let classes: [EventClassFilterDTO]
    let students: [EventStudentFilterDTO]
    let eventTypeTitle: (String) -> String
    let parseDate: (String) -> Date?
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (EventFormData) -> Void

    @State private var eventTitle: String
    @State private var eventType: String
    @State private var startsAt: Date
    @State private var description: String
    @State private var selectedClassIDs: Set<Int>
    @State private var selectedStudentIDs: Set<Int>
    @State private var validationMessage: String?

    init(
        mode: Mode,
        event: EventTimelineDTO?,
        eventTypes: [String],
        classes: [EventClassFilterDTO],
        students: [EventStudentFilterDTO],
        eventTypeTitle: @escaping (String) -> String,
        parseDate: @escaping (String) -> Date?,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (EventFormData) -> Void
    ) {
        self.mode = mode
        self.event = event
        self.eventTypes = eventTypes
        self.classes = classes
        self.students = students
        self.eventTypeTitle = eventTypeTitle
        self.parseDate = parseDate
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _eventTitle = State(initialValue: event?.title ?? "")
        _eventType = State(initialValue: event?.event_type ?? eventTypes.first ?? "class")
        _startsAt = State(initialValue: event.flatMap { parseDate($0.starts_at) } ?? Date())
        _description = State(initialValue: event?.description ?? "")
        _selectedClassIDs = State(initialValue: Set(event?.class_ids ?? []))
        _selectedStudentIDs = State(initialValue: Set(event?.student_ids ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                mainSection
                audienceSection

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
            TextField("Название", text: $eventTitle)

            Picker("Тип", selection: $eventType) {
                ForEach(eventTypes, id: \.self) { type in
                    Text(eventTypeTitle(type)).tag(type)
                }
            }

            DatePicker(
                "Дата и время",
                selection: $startsAt,
                displayedComponents: [.date, .hourAndMinute]
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Описание")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }
        }
    }

    private var audienceSection: some View {
        Section {
            if classes.isEmpty && students.isEmpty {
                Text("Фильтры классов и учеников не загружены.")
                    .foregroundStyle(.secondary)
            }

            if !classes.isEmpty {
                DisclosureGroup("Классы: \(selectedClassIDs.count)") {
                    ForEach(classes) { item in
                        Toggle(
                            item.name,
                            isOn: bindingForClass(item.id)
                        )
                    }
                }
            }

            if !students.isEmpty {
                DisclosureGroup("Ученики: \(selectedStudentIDs.count)") {
                    ForEach(students) { item in
                        Toggle(
                            item.student_name,
                            isOn: bindingForStudent(item.id)
                        )
                    }
                }
            }

            Button {
                selectedClassIDs.removeAll()
                selectedStudentIDs.removeAll()
            } label: {
                Label("Очистить участников", systemImage: "xmark.circle")
            }
            .disabled(selectedClassIDs.isEmpty && selectedStudentIDs.isEmpty)
        } header: {
            Text("Участники")
        } footer: {
            Text("Если не выбрать классы или учеников, событие будет создано без привязки к конкретной аудитории либо для общей аудитории — зависит от логики сервера.")
        }
    }

    private func bindingForClass(_ id: Int) -> Binding<Bool> {
        Binding(
            get: {
                selectedClassIDs.contains(id)
            },
            set: { isSelected in
                if isSelected {
                    selectedClassIDs.insert(id)
                } else {
                    selectedClassIDs.remove(id)
                }
            }
        )
    }

    private func bindingForStudent(_ id: Int) -> Binding<Bool> {
        Binding(
            get: {
                selectedStudentIDs.contains(id)
            },
            set: { isSelected in
                if isSelected {
                    selectedStudentIDs.insert(id)
                } else {
                    selectedStudentIDs.remove(id)
                }
            }
        )
    }

    private func save() {
        validationMessage = nil

        let cleanTitle = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            validationMessage = "Введите название события"
            return
        }

        let formData = EventFormData(
            title: cleanTitle,
            eventType: eventType,
            startsAt: startsAt,
            description: cleanDescription,
            classIDs: Array(selectedClassIDs).sorted(),
            studentIDs: Array(selectedStudentIDs).sorted()
        )

        onSave(formData)
        dismiss()
    }
}