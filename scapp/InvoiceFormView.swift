import SwiftUI

struct InvoiceFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новый счёт"
            case .edit:
                return "Редактирование счёта"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let invoice: InvoiceDTO?
    let students: [FinanceStudentFilterDTO]
    let periods: [FinancePeriodDTO]
    let statuses: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (InvoiceFormData) -> Void

    @State private var studentID: Int
    @State private var title: String
    @State private var description: String
    @State private var amount: String
    @State private var dueDate: String
    @State private var period: String
    @State private var status: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        invoice: InvoiceDTO?,
        students: [FinanceStudentFilterDTO],
        periods: [FinancePeriodDTO],
        statuses: [(code: String, title: String)],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (InvoiceFormData) -> Void
    ) {
        self.mode = mode
        self.invoice = invoice
        self.students = students
        self.periods = periods
        self.statuses = statuses
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _studentID = State(initialValue: invoice?.student_id ?? students.first?.id ?? 0)
        _title = State(initialValue: invoice?.title ?? "")
        _description = State(initialValue: invoice?.description ?? "")
        _amount = State(initialValue: invoice?.amount ?? "")
        _dueDate = State(initialValue: invoice?.due_date ?? "")
        _period = State(initialValue: invoice?.billing_period ?? periods.first?.code ?? "")
        _status = State(initialValue: invoice?.status ?? "new")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ученик") {
                    if students.isEmpty {
                        Text("Список учеников не загружен.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Ученик", selection: $studentID) {
                            Text("Выберите ученика").tag(0)

                            ForEach(students) { student in
                                Text(student.student_name).tag(student.id)
                            }
                        }
                    }
                }

                Section("Счёт") {
                    TextField("Название", text: $title)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $description)
                            .frame(minHeight: 90)
                    }

                    TextField("Сумма", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Срок оплаты, yyyy-MM-dd", text: $dueDate)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Период и статус") {
                    if periods.isEmpty {
                        TextField("Период", text: $period)
                    } else {
                        Picker("Период", selection: $period) {
                            Text("Не указан").tag("")

                            ForEach(periods) { item in
                                Text(item.title).tag(item.code)
                            }
                        }
                    }

                    Picker("Статус", selection: $status) {
                        ForEach(statuses.filter { $0.code != "all" }, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }
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
                            Text("Сохранить")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard studentID != 0 else {
            validationMessage = "Выберите ученика"
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDueDate = dueDate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            validationMessage = "Введите название счёта"
            return
        }

        guard !cleanAmount.isEmpty else {
            validationMessage = "Введите сумму"
            return
        }

        guard !cleanDueDate.isEmpty else {
            validationMessage = "Укажите срок оплаты"
            return
        }

        let formData = InvoiceFormData(
            studentID: studentID,
            title: cleanTitle,
            description: description,
            amount: cleanAmount,
            dueDate: cleanDueDate,
            period: period,
            status: status
        )

        onSave(formData)
        dismiss()
    }
}