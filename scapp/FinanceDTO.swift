import Foundation

// MARK: - Finance filters

struct FinanceFiltersResponseDTO: Codable {
    let students: [FinanceStudentFilterDTO]
    let periods: [FinancePeriodDTO]
    let next_month: FinanceNextMonthDTO?
}

struct FinanceStudentFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int?
    let class_id: Int?
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let student_name: String
    let class_name: String?
}

struct FinancePeriodDTO: Codable, Identifiable, Hashable {
    let billing_period: String

    var id: String {
        billing_period
    }

    var code: String {
        billing_period
    }

    var title: String {
        billing_period
    }
}

struct FinanceNextMonthDTO: Codable, Hashable {
    let billing_period: String?
    let label: String?
    let period_starts_at: String?
    let period_ends_at: String?
    let due_date: String?
}

// MARK: - Finance overview

struct FinanceOverviewResponseDTO: Codable, Hashable {
    let invoices_count: Int?
    let total_amount: String?
    let paid_amount: String?
    let debt_amount: String?
    let overdue_count: Int?
    let paid_count: Int?
    let payable_count: Int?
    let next_billing_period: String?
    let next_billing_period_label: String?
    let next_period_starts_at: String?
    let next_period_ends_at: String?
    let next_due_date: String?

    var total_invoices: Int? {
        invoices_count
    }

    var paid_invoices: Int? {
        paid_count
    }

    var unpaid_invoices: Int? {
        payable_count
    }

    var overdue_invoices: Int? {
        overdue_count
    }
}

// MARK: - Invoices

struct InvoicesListResponseDTO: Codable {
    let items: [InvoiceDTO]
}

struct InvoiceDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let student_name: String
    let class_name: String?
    let title: String
    let description: String?
    let invoice_type: String?
    let amount: String
    let due_date: String?
    let status: String
    let billing_period: String?
    let period_starts_at: String?
    let period_ends_at: String?
    let created_at: String?
    let updated_at: String?
    let paid_amount: String?
    let debt_amount: String?
    let paid_percent: String?
    let is_overdue: Bool?

    var period: String? {
        billing_period
    }

    var remainingAmount: String {
        if let debtAmount = debt_amount {
            return debtAmount
        }

        guard let paidAmount = paid_amount,
              let total = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              let paid = Decimal(string: paidAmount.replacingOccurrences(of: ",", with: ".")) else {
            return amount
        }

        return "\(max(total - paid, 0))"
    }

    var isPaid: Bool {
        status == "paid"
    }

    var isOverdue: Bool {
        status == "overdue" || is_overdue == true
    }

    var isCancelled: Bool {
        status == "cancelled" || status == "canceled"
    }
}

struct InvoiceFormData: Hashable {
    let studentID: Int
    let title: String
    let description: String
    let amount: String
    let dueDate: String
    let period: String
    let status: String
}

struct InvoiceCreateRequestDTO: Codable {
    let student_id: Int
    let title: String
    let description: String?
    let amount: String
    let due_date: String?
    let billing_period: String?
    let status: String?
}

struct InvoiceUpdateRequestDTO: Codable {
    let student_id: Int
    let title: String
    let description: String?
    let amount: String
    let due_date: String?
    let billing_period: String?
    let status: String?
}

struct InvoiceIDStatusResponseDTO: Codable {
    let id: Int?
    let status: String?
    let message: String?
}

// MARK: - Payments

struct PaymentsListResponseDTO: Codable {
    let items: [PaymentDTO]
}

struct PaymentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let invoice_id: Int
    let amount: String
    let paid_at: String?
    let payment_method: String?
    let external_id: String?
    let comment: String?
    let created_by_user_id: Int?
    let created_at: String?
    let created_by_name: String?

    var payment_date: String? {
        paid_at
    }
}

struct PaymentFormData: Hashable {
    let invoiceID: Int
    let amount: String
    let paymentDate: String
    let paymentMethod: String
    let comment: String
}

struct PaymentCreateRequestDTO: Codable {
    let invoice_id: Int
    let amount: String
    let paid_at: String?
    let payment_method: String?
    let comment: String?
}

struct PaymentUpdateRequestDTO: Codable {
    let invoice_id: Int
    let amount: String
    let paid_at: String?
    let payment_method: String?
    let comment: String?
}

struct PaymentIDStatusResponseDTO: Codable {
    let id: Int?
    let status: String?
    let message: String?
}

// MARK: - Existing next month generation

struct FinanceNextMonthResponseDTO: Codable {
    let status: String?
    let created_count: Int?
    let message: String?
}

// MARK: - Billing settings

struct BillingSettingsDTO: Codable, Hashable {
    let monthly_amount: String?
    let invoice_title_template: String?
    let invoice_description_template: String?
    let due_day: Int?
    let vacation_discount_enabled: Bool?
    let vacation_daily_rate: String?
    let min_working_days_for_full_charge: Int?
    let updated_at: String?
}

struct BillingSettingsFormData: Hashable {
    var monthlyAmount: String
    var invoiceTitleTemplate: String
    var invoiceDescriptionTemplate: String
    var dueDay: String
    var vacationDiscountEnabled: Bool
    var vacationDailyRate: String
    var minWorkingDaysForFullCharge: String

    init(settings: BillingSettingsDTO? = nil) {
        monthlyAmount = settings?.monthly_amount ?? ""
        invoiceTitleTemplate = settings?.invoice_title_template ?? "Оплата за обучение"
        invoiceDescriptionTemplate = settings?.invoice_description_template ?? ""
        dueDay = settings?.due_day.map(String.init) ?? "10"
        vacationDiscountEnabled = settings?.vacation_discount_enabled ?? true
        vacationDailyRate = settings?.vacation_daily_rate ?? ""
        minWorkingDaysForFullCharge = settings?.min_working_days_for_full_charge.map(String.init) ?? ""
    }
}

// MARK: - Working days

struct WorkingDaysResponseDTO: Codable, Hashable {
    let billing_period: String?
    let working_days: [WorkingDayDTO]
    let total_working_days: Int?
}

struct WorkingDayDTO: Codable, Identifiable, Hashable {
    let date: String
    let is_working: Bool
    let comment: String?

    var id: String {
        date
    }
}

struct WorkingDaysSaveRequestDTO: Codable {
    let billing_period: String
    let working_days: [WorkingDaySaveDTO]
}

struct WorkingDaySaveDTO: Codable, Hashable {
    let date: String
    let is_working: Bool
    let comment: String?
}

// MARK: - Student vacation

struct StudentVacationDTO: Codable, Hashable {
    let student_id: Int
    let student_name: String?
    let billing_period: String?
    let balance_days: Int?
    let used_days: Int?
    let available_days: Int?
    let vacation_days: [StudentVacationDayDTO]
}

struct StudentVacationDayDTO: Codable, Identifiable, Hashable {
    let date: String
    let comment: String?

    var id: String {
        date
    }
}

struct VacationBalanceSaveRequestDTO: Codable {
    let billing_period: String?
    let balance_days: Int
}

struct VacationDaysSaveRequestDTO: Codable {
    let billing_period: String?
    let vacation_days: [StudentVacationDaySaveDTO]
}

struct StudentVacationDaySaveDTO: Codable, Hashable {
    let date: String
    let comment: String?
}

// MARK: - Monthly invoices preview / generation

struct MonthlyInvoicesPreviewRequestDTO: Codable {
    let billing_period: String
    let period_starts_at: String
    let period_ends_at: String
    let due_date: String
}

struct MonthlyInvoicesPreviewResponseDTO: Codable, Hashable {
    let billing_period: String?
    let period_starts_at: String?
    let period_ends_at: String?
    let due_date: String?
    let total_count: Int?
    let total_amount: String?
    let items: [MonthlyInvoicePreviewItemDTO]
}

struct MonthlyInvoicePreviewItemDTO: Codable, Identifiable, Hashable {
    let student_id: Int
    let student_name: String
    let class_name: String?
    let amount: String
    let base_amount: String?
    let discount_amount: String?
    let working_days: Int?
    let vacation_days: Int?
    let payable_days: Int?
    let comment: String?

    var id: Int {
        student_id
    }
}

struct MonthlyDetailedGenerationResponseDTO: Codable, Hashable {
    let status: String?
    let created_count: Int?
    let skipped_count: Int?
    let total_amount: String?
    let message: String?
}

// MARK: - Invoice items / parent-visible explanation

struct InvoiceItemsListResponseDTO: Codable, Hashable {
    let items: [InvoiceItemDTO]
}

struct InvoiceItemDTO: Codable, Identifiable, Hashable {
    let id: Int
    let invoice_id: Int?
    let title: String
    let description: String?
    let item_type: String?
    let quantity: String?
    let unit_price: String?
    let amount: String
    let date_from: String?
    let date_to: String?
    let meta: [String: String]?

    var readableType: String {
        switch item_type {
        case "base":
            return "Основное начисление"
        case "discount":
            return "Скидка"
        case "vacation":
            return "Отпуск / перерасчёт"
        case "payment":
            return "Платёж"
        case "adjustment":
            return "Корректировка"
        default:
            return item_type ?? "Начисление"
        }
    }
}

// MARK: - Legal entities

struct FinanceLegalEntitiesListResponseDTO: Codable {
    let items: [FinanceLegalEntityDTO]
}

struct FinanceLegalEntityDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let inn: String?
    let kpp: String?
    let bank_name: String?
    let bik: String?
    let account: String?
    let correspondent_account: String?
    let is_default: Bool?
    let is_active: Bool?
    let created_at: String?
    let updated_at: String?
}

struct FinanceLegalEntityFormData: Hashable {
    var name: String = ""
    var inn: String = ""
    var kpp: String = ""
    var bankName: String = ""
    var bik: String = ""
    var account: String = ""
    var correspondentAccount: String = ""
    var isDefault: Bool = false
    var isActive: Bool = true

    init() {}

    init(entity: FinanceLegalEntityDTO) {
        name = entity.name
        inn = entity.inn ?? ""
        kpp = entity.kpp ?? ""
        bankName = entity.bank_name ?? ""
        bik = entity.bik ?? ""
        account = entity.account ?? ""
        correspondentAccount = entity.correspondent_account ?? ""
        isDefault = entity.is_default ?? false
        isActive = entity.is_active ?? true
    }
}

// MARK: - Payer INNs

struct StudentPayerInnsListResponseDTO: Codable {
    let items: [StudentPayerInnDTO]
}

struct StudentPayerInnDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let student_name: String?
    let payer_name: String
    let inn: String
    let comment: String?
    let is_active: Bool?
    let created_at: String?
    let updated_at: String?
}

struct StudentPayerInnFormData: Hashable {
    var studentID: Int = 0
    var payerName: String = ""
    var inn: String = ""
    var comment: String = ""
    var isActive: Bool = true

    init() {}

    init(item: StudentPayerInnDTO) {
        studentID = item.student_id
        payerName = item.payer_name
        inn = item.inn
        comment = item.comment ?? ""
        isActive = item.is_active ?? true
    }
}

// MARK: - Bank statements

struct BankStatementImportsListResponseDTO: Codable {
    let items: [BankStatementImportDTO]
}

struct BankStatementImportDTO: Codable, Identifiable, Hashable {
    let id: Int
    let source: String?
    let filename: String?
    let status: String?
    let operations_count: Int?
    let matched_count: Int?
    let created_at: String?
    let message: String?
}

struct BankStatementOperationsListResponseDTO: Codable {
    let items: [BankStatementOperationDTO]
}

struct BankStatementOperationDTO: Codable, Identifiable, Hashable {
    let id: Int
    let import_id: Int?
    let operation_date: String?
    let amount: String
    let payer_name: String?
    let payer_inn: String?
    let payment_purpose: String?
    let matched_invoice_id: Int?
    let matched_student_name: String?
    let status: String?
    let created_at: String?
}