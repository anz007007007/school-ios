import SwiftUI

struct MessageComposeView: View {
    enum Mode {
        case single
        case bulk

        var title: String {
            switch self {
            case .single:
                return "Новое сообщение"
            case .bulk:
                return "Рассылка"
            }
        }

        var buttonTitle: String {
            switch self {
            case .single:
                return "Отправить"
            case .bulk:
                return "Разослать"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let contacts: [MessageContactDTO]
    let initialRecipientID: Int?
    let isSaving: Bool
    let errorMessage: String?
    let onSendSingle: (MessageCreateFormData) -> Void
    let onSendBulk: (MessageBulkFormData) -> Void

    @State private var recipientUserID: Int = 0
    @State private var selectedRecipientIDs: Set<Int> = []
    @State private var subject: String = ""
    @State private var bodyText: String = ""
    @State private var isImportant = false
    @State private var selectedRole: String = "all"
    @State private var validationMessage: String?
    @State private var contactSearchText = ""

    init(
        mode: Mode,
        contacts: [MessageContactDTO],
        initialRecipientID: Int? = nil,
        isSaving: Bool,
        errorMessage: String?,
        onSendSingle: @escaping (MessageCreateFormData) -> Void,
        onSendBulk: @escaping (MessageBulkFormData) -> Void
    ) {
        self.mode = mode
        self.contacts = contacts
        self.initialRecipientID = initialRecipientID
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSendSingle = onSendSingle
        self.onSendBulk = onSendBulk

        let firstContactID = Self.uniqueContacts(from: contacts)
            .sorted { $0.displayTitle < $1.displayTitle }
            .first?
            .id ?? 0

        _recipientUserID = State(initialValue: initialRecipientID ?? firstContactID)
    }

    var body: some View {
        NavigationStack {
            Form {
                recipientsSection
                contentSection

                Section("Параметры") {
                    Toggle("Важное", isOn: $isImportant)
                        .tint(AppTheme.primaryDark)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка отправки", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.danger)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        send()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(mode.buttonTitle)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var recipientsSection: some View {
        Section("Получатели") {
            if uniqueContacts.isEmpty {
                Text("Контакты не загружены. Обновите раздел сообщений.")
                    .foregroundStyle(AppTheme.muted)
            } else {
                rolePicker

                if mode == .single {
                    selectedRecipientRow

                    NavigationLink {
                        MessageRecipientSelectionView(
                            contacts: filteredContacts,
                            selectedRecipientID: $recipientUserID,
                            searchText: $contactSearchText
                        )
                    } label: {
                        Label("Выбрать получателя", systemImage: "person.crop.circle.badge.plus")
                    }

                    if filteredContacts.isEmpty {
                        Text("В выбранной группе контактов нет.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                } else {
                    bulkRecipientsView
                }
            }
        }
    }

    private var rolePicker: some View {
        Picker(mode == .single ? "Группа" : "Роль", selection: $selectedRole) {
            Text("Все").tag("all")
            Text("Администрация").tag("admin")
            Text("Учителя").tag("teacher")
            Text("Родители").tag("parent")
            Text("Ученики").tag("student")

            if mode == .bulk {
                Text("Повара").tag("cook")
            }
        }
        .onChange(of: selectedRole) {
            if mode == .single {
                recipientUserID = filteredContacts.first?.id ?? 0
            } else {
                selectedRecipientIDs.removeAll()
            }
        }
    }

    @ViewBuilder
    private var selectedRecipientRow: some View {
        if let selectedContact = uniqueContacts.first(where: { $0.id == recipientUserID }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Получатель")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                HStack(spacing: 10) {
                    Image(systemName: iconName(for: selectedContact.role_code))
                        .foregroundStyle(AppTheme.control)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedContact.full_name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Text(selectedContact.displayTitle.replacingOccurrences(of: "\(selectedContact.full_name) · ", with: ""))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()
                }
            }
            .padding(.vertical, 4)
        } else {
            Text("Получатель не выбран")
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var bulkRecipientsView: some View {
        Group {
            DisclosureGroup("Получатели: \(selectedRecipientIDs.count)") {
                ForEach(filteredContacts) { contact in
                    Toggle(
                        contact.displayTitle,
                        isOn: bindingForRecipient(contact.id)
                    )
                    .tint(AppTheme.primaryDark)
                }
            }

            Button {
                selectedRecipientIDs = Set(filteredContacts.map { $0.id })
            } label: {
                Label("Выбрать всех в фильтре", systemImage: "checkmark.circle")
            }

            Button {
                selectedRecipientIDs.removeAll()
            } label: {
                Label("Очистить выбор", systemImage: "xmark.circle")
            }
            .disabled(selectedRecipientIDs.isEmpty)
        }
    }

    private var contentSection: some View {
        Section("Сообщение") {
            TextField("Тема", text: $subject)

            VStack(alignment: .leading, spacing: 8) {
                Text("Текст")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                TextEditor(text: $bodyText)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.cardSoft.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var uniqueContacts: [MessageContactDTO] {
        Self.uniqueContacts(from: contacts)
    }

    private var filteredContacts: [MessageContactDTO] {
        var result = uniqueContacts

        if selectedRole != "all" {
            result = result.filter { $0.role_code == selectedRole }
        }

        let query = contactSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !query.isEmpty {
            result = result.filter {
                $0.normalizedSearchText.contains(query)
            }
        }

        return result.sorted {
            $0.displayTitle < $1.displayTitle
        }
    }

    private static func uniqueContacts(from contacts: [MessageContactDTO]) -> [MessageContactDTO] {
        var result: [MessageContactDTO] = []
        var seenIDs = Set<Int>()

        for contact in contacts.sorted(by: { $0.displayTitle < $1.displayTitle }) {
            guard !seenIDs.contains(contact.id) else {
                continue
            }

            seenIDs.insert(contact.id)
            result.append(contact)
        }

        return result
    }

    private func bindingForRecipient(_ id: Int) -> Binding<Bool> {
        Binding(
            get: {
                selectedRecipientIDs.contains(id)
            },
            set: { isSelected in
                if isSelected {
                    selectedRecipientIDs.insert(id)
                } else {
                    selectedRecipientIDs.remove(id)
                }
            }
        )
    }

    private func iconName(for roleCode: String) -> String {
        switch roleCode {
        case "admin":
            return "person.badge.key.fill"
        case "teacher":
            return "person.text.rectangle.fill"
        case "parent":
            return "figure.2.and.child.holdinghands"
        case "student":
            return "graduationcap.fill"
        case "cook":
            return "fork.knife.circle.fill"
        default:
            return "person.fill"
        }
    }

    private func send() {
        validationMessage = nil

        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanSubject.isEmpty else {
            validationMessage = "Введите тему"
            return
        }

        guard !cleanBody.isEmpty else {
            validationMessage = "Введите текст сообщения"
            return
        }

        switch mode {
        case .single:
            guard recipientUserID != 0 else {
                validationMessage = "Выберите получателя"
                return
            }

            onSendSingle(
                MessageCreateFormData(
                    recipientUserID: recipientUserID,
                    subject: cleanSubject,
                    body: cleanBody,
                    isImportant: isImportant
                )
            )

        case .bulk:
            guard !selectedRecipientIDs.isEmpty else {
                validationMessage = "Выберите хотя бы одного получателя"
                return
            }

            onSendBulk(
                MessageBulkFormData(
                    recipientUserIDs: Array(selectedRecipientIDs).sorted(),
                    subject: cleanSubject,
                    body: cleanBody,
                    isImportant: isImportant
                )
            )
        }

        dismiss()
    }
}

struct MessageRecipientSelectionView: View {
    let contacts: [MessageContactDTO]
    @Binding var selectedRecipientID: Int
    @Binding var searchText: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if contacts.isEmpty {
                ContentUnavailableView(
                    "Получатели не найдены",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Измените группу или поиск.")
                )
            } else {
                ForEach(contacts) { contact in
                    Button {
                        selectedRecipientID = contact.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconName(for: contact.role_code))
                                .foregroundStyle(AppTheme.control)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.full_name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)

                                Text(contact.displayTitle.replacingOccurrences(of: "\(contact.full_name) · ", with: ""))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }

                            Spacer()

                            if selectedRecipientID == contact.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Получатель")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Поиск получателя")
    }

    private func iconName(for roleCode: String) -> String {
        switch roleCode {
        case "admin":
            return "person.badge.key.fill"
        case "teacher":
            return "person.text.rectangle.fill"
        case "parent":
            return "figure.2.and.child.holdinghands"
        case "student":
            return "graduationcap.fill"
        case "cook":
            return "fork.knife.circle.fill"
        default:
            return "person.fill"
        }
    }
}