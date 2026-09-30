import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новый платёж"
            case .edit:
                return "Редактирование платежа"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let payment: PaymentDTO?
    let invoice: InvoiceDTO
    let paymentMethods: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (PaymentFormData) -> Void

    @State private var amount: String
    @State private var paymentDate: String
    @State private var paymentMethod: String
    @State private var comment: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        payment: PaymentDTO?,
        invoice: InvoiceDTO,
        paymentMethods: [(code: String, title: String)],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (PaymentFormData) -> Void
    ) {
        self.mode = mode
        self.payment = payment
        self.invoice = invoice
        self.paymentMethods = paymentMethods
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _amount = State(initialValue: payment?.amount ?? "")
        _paymentDate = State(initialValue: payment?.payment_date ?? Self.todayString)
        _paymentMethod = State(initialValue: payment?.payment_method ?? "cash")
        _comment = State(initialValue: payment?.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Счёт") {
                    LabeledContent("Название", value: invoice.title)
                    LabeledContent("Ученик", value: invoice.student_name)
                    LabeledContent("Сумма", value: invoice.amount)
                }

                Section("Платёж") {
                    TextField("Сумма", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Дата, yyyy-MM-dd", text: $paymentDate)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Способ оплаты", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Комментарий")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $comment)
                            .frame(minHeight: 90)
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

        let cleanAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanAmount.isEmpty else {
            validationMessage = "Введите сумму платежа"
            return
        }

        let formData = PaymentFormData(
            invoiceID: invoice.id,
            amount: cleanAmount,
            paymentDate: paymentDate,
            paymentMethod: paymentMethod,
            comment: comment
        )

        onSave(formData)
        dismiss()
    }

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date())
    }
}