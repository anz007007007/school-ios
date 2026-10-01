import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class FinanceViewModel: ObservableObject {
    @Published var invoices: [InvoiceDTO] = []
    @Published var payments: [PaymentDTO] = []
    @Published var students: [FinanceStudentFilterDTO] = []
    @Published var periods: [FinancePeriodDTO] = []
    @Published var overview: FinanceOverviewResponseDTO?
    @Published var filtersNextMonthDTO: FinanceNextMonthDTO?

    @Published var selectedStudentID: Int = 0
    @Published var selectedPeriod: String = "all"
    @Published var selectedStatus: String = "unpaid"
    @Published var selectedInvoiceID: Int?
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isLoadingPayments = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var billingSettings: BillingSettingsDTO?
    @Published var workingDays: [WorkingDayDTO] = []
    @Published var workingDaysPeriod: String = ""
    @Published var studentVacation: StudentVacationDTO?
    @Published var monthlyPreview: MonthlyInvoicesPreviewResponseDTO?
    @Published var invoiceItems: [InvoiceItemDTO] = []
    @Published var legalEntities: [FinanceLegalEntityDTO] = []
    @Published var payerInns: [StudentPayerInnDTO] = []
    @Published var bankStatementImports: [BankStatementImportDTO] = []
    @Published var bankStatementOperations: [BankStatementOperationDTO] = []
    @Published var isLoadingAdminFinance = false

    let statuses: [(code: String, title: String)] = [
        ("unpaid", "Не оплачено"),
        ("all", "Все"),
        ("new", "Новый"),
        ("partial", "Частично"),
        ("paid", "Оплачено"),
        ("overdue", "Просрочено"),
        ("cancelled", "Отменено")
    ]

    let paymentMethods: [(code: String, title: String)] = [
        ("cash", "Наличные"),
        ("card", "Карта"),
        ("bank_transfer", "Перевод"),
        ("online", "Онлайн"),
        ("other", "Другое")
    ]

    var filteredInvoices: [InvoiceDTO] {
        var result = invoices

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        if selectedPeriod != "all" {
            result = result.filter { $0.billing_period == selectedPeriod }
        }

        if selectedStatus == "unpaid" {
            result = result.filter {
                $0.status == "new"
                || $0.status == "partial"
                || $0.status == "overdue"
                || $0.is_overdue == true
            }
        } else if selectedStatus != "all" {
            result = result.filter { $0.status == selectedStatus }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { invoice in
                invoice.student_name.localizedCaseInsensitiveContains(query)
                || (invoice.class_name ?? "").localizedCaseInsensitiveContains(query)
                || invoice.title.localizedCaseInsensitiveContains(query)
                || (invoice.description ?? "").localizedCaseInsensitiveContains(query)
                || (invoice.invoice_type ?? "").localizedCaseInsensitiveContains(query)
                || invoice.amount.localizedCaseInsensitiveContains(query)
                || invoice.status.localizedCaseInsensitiveContains(query)
                || (invoice.billing_period ?? "").localizedCaseInsensitiveContains(query)
                || (invoice.due_date ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.due_date ?? "") < ($1.due_date ?? "")
        }
    }

    var selectedInvoice: InvoiceDTO? {
        guard let selectedInvoiceID else {
            return nil
        }

        return invoices.first { $0.id == selectedInvoiceID }
    }

    var totalAmountText: String {
        overview?.total_amount ?? invoices.reduce(Decimal(0)) { partial, invoice in
            partial + decimal(from: invoice.amount)
        }.description
    }

    var paidAmountText: String {
        overview?.paid_amount ?? invoices.reduce(Decimal(0)) { partial, invoice in
            partial + decimal(from: invoice.paid_amount ?? "0")
        }.description
    }

    var debtAmountText: String {
        overview?.debt_amount ?? invoices.reduce(Decimal(0)) { partial, invoice in
            partial + decimal(from: invoice.debt_amount ?? invoice.remainingAmount)
        }.description
    }

    var unpaidCount: Int {
        overview?.unpaid_invoices ?? invoices.filter { $0.status == "new" || $0.status == "partial" }.count
    }

    var overdueCount: Int {
        overview?.overdue_invoices ?? invoices.filter { $0.status == "overdue" || $0.is_overdue == true }.count
    }

    private var filtersNextMonth: FinanceNextMonthPayload? {
        guard let nextMonth = filtersNextMonthDTO else {
            return nil
        }

        return FinanceNextMonthPayload(
            billingPeriod: nextMonth.billing_period,
            periodStartsAt: nextMonth.period_starts_at,
            periodEndsAt: nextMonth.period_ends_at,
            dueDate: nextMonth.due_date
        )
    }

    private var overviewNextMonth: FinanceNextMonthPayload? {
        guard overview?.next_billing_period != nil
                || overview?.next_period_starts_at != nil
                || overview?.next_period_ends_at != nil
                || overview?.next_due_date != nil else {
            return nil
        }

        return FinanceNextMonthPayload(
            billingPeriod: overview?.next_billing_period,
            periodStartsAt: overview?.next_period_starts_at,
            periodEndsAt: overview?.next_period_ends_at,
            dueDate: overview?.next_due_date
        )
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let overviewTask: Void = loadOverview(api: api)
        async let invoicesTask: Void = loadInvoices(api: api, showLoading: false)

        _ = await (filtersTask, overviewTask, invoicesTask)

        isLoading = false
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(FinanceFiltersResponseDTO.self, from: data)
            students = decoded.students
            periods = decoded.periods
            filtersNextMonthDTO = decoded.next_month
        } catch {
            errorMessage = "Не удалось загрузить фильтры финансов: \(error.localizedDescription)"
        }

        isLoadingFilters = false
    }

    func loadOverview(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/overview",
                method: "GET"
            )

            overview = try JSONDecoder().decode(FinanceOverviewResponseDTO.self, from: data)
        } catch {
            // Не блокируем экран, если обзор не загрузился.
        }
    }

    func loadInvoices(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if selectedPeriod != "all" {
                queryItems.append(URLQueryItem(name: "billing_period", value: selectedPeriod))
            }

            // Для unpaid не отправляем фильтр по статусу на сервер,
            // загружаем все счета и фильтруем на клиенте
            if selectedStatus != "all" && selectedStatus != "unpaid" {
                queryItems.append(URLQueryItem(name: "status", value: selectedStatus))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(InvoicesListResponseDTO.self, from: data)
            invoices = decoded.items

            if selectedInvoiceID == nil {
                selectedInvoiceID = invoices.first?.id
            }

            if let selectedInvoiceID {
                await loadPayments(api: api, invoiceID: selectedInvoiceID, showLoading: false)
            }
        } catch {
            errorMessage = "Не удалось загрузить счета: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadPayments(
        api: SchoolAPI,
        invoiceID: Int,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoadingPayments = true
        }

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices/\(invoiceID)/payments",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(PaymentsListResponseDTO.self, from: data)
            payments = decoded.items
            selectedInvoiceID = invoiceID
        } catch {
            errorMessage = "Не удалось загрузить платежи: \(error.localizedDescription)"
        }

        if showLoading {
            isLoadingPayments = false
        }
    }

    func loadInvoiceItems(api: SchoolAPI, invoiceID: Int) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices/\(invoiceID)/items",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(InvoiceItemsListResponseDTO.self, from: data)
            invoiceItems = decoded.items
        } catch {
            invoiceItems = []
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        await loadInvoices(api: api)
        await loadOverview(api: api)
    }

    func createInvoice(
        api: SchoolAPI,
        formData: InvoiceFormData
    ) async -> Bool {
        await saveInvoice(
            api: api,
            invoiceID: nil,
            formData: formData
        )
    }

    func updateInvoice(
        api: SchoolAPI,
        invoiceID: Int,
        formData: InvoiceFormData
    ) async -> Bool {
        await saveInvoice(
            api: api,
            invoiceID: invoiceID,
            formData: formData
        )
    }

    private func saveInvoice(
        api: SchoolAPI,
        invoiceID: Int?,
        formData: InvoiceFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanTitle = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAmount = formData.amount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard formData.studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        guard !cleanTitle.isEmpty else {
            errorMessage = "Введите название счёта"
            isSaving = false
            return false
        }

        guard !cleanAmount.isEmpty else {
            errorMessage = "Введите сумму"
            isSaving = false
            return false
        }

        guard let dueDate = cleanOptional(formData.dueDate) else {
            errorMessage = "Укажите срок оплаты"
            isSaving = false
            return false
        }

        do {
            var body: [String: Any] = [
                "student_id": formData.studentID,
                "title": cleanTitle,
                "amount": cleanAmount,
                "status": formData.status,
                "due_date": dueDate
            ]

            if let description = cleanOptional(formData.description) {
                body["description"] = description
            }

            if let period = cleanOptional(formData.period) {
                body["billing_period"] = period
            }

            let path: String
            let method: String

            if let invoiceID {
                path = "/api/v1/finance/invoices/\(invoiceID)"
                method = "PUT"
            } else {
                path = "/api/v1/finance/invoices"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = invoiceID == nil ? "Счёт создан" : "Счёт обновлён"

            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = invoiceID == nil
                ? "Не удалось создать счёт: \(error.localizedDescription)"
                : "Не удалось обновить счёт: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func cancelInvoice(
        api: SchoolAPI,
        invoice: InvoiceDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices/\(invoice.id)",
                method: "DELETE"
            )

            successMessage = "Счёт отменён"
            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отменить счёт: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createPayment(
        api: SchoolAPI,
        formData: PaymentFormData
    ) async -> Bool {
        await savePayment(
            api: api,
            paymentID: nil,
            formData: formData
        )
    }

    func updatePayment(
        api: SchoolAPI,
        paymentID: Int,
        formData: PaymentFormData
    ) async -> Bool {
        await savePayment(
            api: api,
            paymentID: paymentID,
            formData: formData
        )
    }

    private func savePayment(
        api: SchoolAPI,
        paymentID: Int?,
        formData: PaymentFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanAmount = formData.amount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard formData.invoiceID != 0 else {
            errorMessage = "Выберите счёт"
            isSaving = false
            return false
        }

        guard !cleanAmount.isEmpty else {
            errorMessage = "Введите сумму платежа"
            isSaving = false
            return false
        }

        do {
            var body: [String: Any] = [
                "invoice_id": formData.invoiceID,
                "amount": cleanAmount
            ]

            if let paymentDate = cleanOptional(formData.paymentDate) {
                body["paid_at"] = paymentDate
            }

            if let method = cleanOptional(formData.paymentMethod) {
                body["payment_method"] = method
            }

            if let comment = cleanOptional(formData.comment) {
                body["comment"] = comment
            }

            let path: String
            let method: String

            if let paymentID {
                path = "/api/v1/finance/payments/\(paymentID)"
                method = "PUT"
            } else {
                path = "/api/v1/finance/payments"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = paymentID == nil ? "Платёж добавлен" : "Платёж обновлён"

            await loadInvoices(api: api, showLoading: false)
            await loadPayments(api: api, invoiceID: formData.invoiceID, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = paymentID == nil
                ? "Не удалось добавить платёж: \(error.localizedDescription)"
                : "Не удалось обновить платёж: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deletePayment(
        api: SchoolAPI,
        payment: PaymentDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/payments/\(payment.id)",
                method: "DELETE"
            )

            successMessage = "Платёж удалён"

            await loadInvoices(api: api, showLoading: false)
            await loadPayments(api: api, invoiceID: payment.invoice_id, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить платёж: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func generateNextMonthInvoices(api: SchoolAPI) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard let nextMonth = overviewNextMonth ?? filtersNextMonth else {
            errorMessage = "Не удалось определить следующий расчётный период"
            isSaving = false
            return false
        }

        guard let billingPeriod = nextMonth.billingPeriod,
              let periodStartsAt = nextMonth.periodStartsAt,
              let periodEndsAt = nextMonth.periodEndsAt,
              let dueDate = nextMonth.dueDate else {
            errorMessage = "Не заполнены параметры следующего месяца"
            isSaving = false
            return false
        }

        let amount = selectedInvoice?.amount ?? invoices.first?.amount ?? ""

        guard !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Не удалось определить сумму для генерации счетов"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "billing_period": billingPeriod,
                "period_starts_at": periodStartsAt,
                "period_ends_at": periodEndsAt,
                "due_date": dueDate,
                "amount": amount
            ]

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/generate-next-month",
                method: "POST",
                body: body
            )

            let decoded = try? JSONDecoder().decode(FinanceNextMonthResponseDTO.self, from: data)

            if let count = decoded?.created_count {
                successMessage = "Счета на следующий месяц созданы: \(count)"
            } else {
                successMessage = "Счета на следующий месяц созданы"
            }

            await loadFilters(api: api)
            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сгенерировать счета: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: billing

    func loadFinanceAdminData(api: SchoolAPI) async {
        isLoadingAdminFinance = true
        errorMessage = nil

        async let settingsTask: Void = loadBillingSettings(api: api)
        async let legalTask: Void = loadLegalEntities(api: api)
        async let payerTask: Void = loadPayerInns(api: api)
        async let importsTask: Void = loadBankStatementImports(api: api)
        async let operationsTask: Void = loadBankStatementOperations(api: api)

        _ = await (
            settingsTask,
            legalTask,
            payerTask,
            importsTask,
            operationsTask
        )

        isLoadingAdminFinance = false
    }

    func loadBillingSettings(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/billing-settings",
                method: "GET"
            )

            billingSettings = try JSONDecoder().decode(BillingSettingsDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить настройки начислений: \(error.localizedDescription)"
        }
    }

    func saveBillingSettings(
        api: SchoolAPI,
        formData: BillingSettingsFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let monthlyAmount = formData.monthlyAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDayText = formData.dueDay.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !monthlyAmount.isEmpty else {
            errorMessage = "Введите месячную стоимость"
            isSaving = false
            return false
        }

        guard let dueDay = Int(dueDayText), (1...31).contains(dueDay) else {
            errorMessage = "День оплаты должен быть числом от 1 до 31"
            isSaving = false
            return false
        }

        var body: [String: Any] = [
            "monthly_amount": monthlyAmount,
            "invoice_title_template": formData.invoiceTitleTemplate,
            "invoice_description_template": formData.invoiceDescriptionTemplate,
            "due_day": dueDay,
            "vacation_discount_enabled": formData.vacationDiscountEnabled
        ]

        if let vacationDailyRate = cleanOptional(formData.vacationDailyRate) {
            body["vacation_daily_rate"] = vacationDailyRate
        }

        if let value = Int(formData.minWorkingDaysForFullCharge.trimmingCharacters(in: .whitespacesAndNewlines)) {
            body["min_working_days_for_full_charge"] = value
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/billing-settings",
                method: "PUT",
                body: body
            )

            successMessage = "Настройки начислений сохранены"
            await loadBillingSettings(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить настройки начислений: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: working days

    func loadWorkingDays(
        api: SchoolAPI,
        billingPeriod: String
    ) async {
        let period = billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !period.isEmpty else {
            errorMessage = "Укажите расчётный период"
            return
        }

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/working-days",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "billing_period", value: period)
                ]
            )

            let decoded = try JSONDecoder().decode(WorkingDaysResponseDTO.self, from: data)
            workingDays = decoded.working_days
            workingDaysPeriod = decoded.billing_period ?? period
        } catch {
            errorMessage = "Не удалось загрузить рабочие дни: \(error.localizedDescription)"
        }
    }

    func saveWorkingDays(
        api: SchoolAPI,
        billingPeriod: String,
        days: [WorkingDayDTO]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let period = billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !period.isEmpty else {
            errorMessage = "Укажите расчётный период"
            isSaving = false
            return false
        }

        let body: [String: Any] = [
            "billing_period": period,
            "working_days": days.map { day in
                [
                    "date": day.date,
                    "is_working": day.is_working,
                    "comment": day.comment ?? ""
                ] as [String: Any]
            }
        ]

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/working-days",
                method: "PUT",
                body: body
            )

            successMessage = "Рабочие дни сохранены"
            await loadWorkingDays(api: api, billingPeriod: period)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить рабочие дни: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: vacation

    func loadStudentVacation(
        api: SchoolAPI,
        studentID: Int,
        billingPeriod: String
    ) async {
        guard studentID != 0 else {
            errorMessage = "Выберите ученика"
            return
        }

        let period = billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var queryItems: [URLQueryItem] = []

            if !period.isEmpty {
                queryItems.append(URLQueryItem(name: "billing_period", value: period))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation",
                method: "GET",
                queryItems: queryItems
            )

            studentVacation = try JSONDecoder().decode(StudentVacationDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить отпуск ученика: \(error.localizedDescription)"
        }
    }

    func saveStudentVacationBalance(
        api: SchoolAPI,
        studentID: Int,
        billingPeriod: String,
        balanceDays: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        var body: [String: Any] = [
            "balance_days": balanceDays
        ]

        if let period = cleanOptional(billingPeriod) {
            body["billing_period"] = period
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation-balance",
                method: "PUT",
                body: body
            )

            successMessage = "Баланс отпускных дней сохранён"
            await loadStudentVacation(api: api, studentID: studentID, billingPeriod: billingPeriod)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить баланс отпуска: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func saveStudentVacationDays(
        api: SchoolAPI,
        studentID: Int,
        billingPeriod: String,
        days: [StudentVacationDayDTO]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        var body: [String: Any] = [
            "vacation_days": days.map { day in
                [
                    "date": day.date,
                    "comment": day.comment ?? ""
                ] as [String: Any]
            }
        ]

        if let period = cleanOptional(billingPeriod) {
            body["billing_period"] = period
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation-days",
                method: "PUT",
                body: body
            )

            successMessage = "Отпускные дни сохранены"
            await loadStudentVacation(api: api, studentID: studentID, billingPeriod: billingPeriod)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить отпускные дни: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: monthly preview and generation

    func previewMonthlyInvoices(
        api: SchoolAPI,
        billingPeriod: String,
        periodStartsAt: String,
        periodEndsAt: String,
        dueDate: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard !billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !periodStartsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !periodEndsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !dueDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Заполните период, даты начала/конца и срок оплаты"
            isSaving = false
            return false
        }

        let body: [String: Any] = [
            "billing_period": billingPeriod,
            "period_starts_at": periodStartsAt,
            "period_ends_at": periodEndsAt,
            "due_date": dueDate
        ]

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices/preview-monthly",
                method: "POST",
                body: body
            )

            monthlyPreview = try JSONDecoder().decode(MonthlyInvoicesPreviewResponseDTO.self, from: data)
            successMessage = "Предпросмотр сформирован"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сформировать предпросмотр: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func generateMonthlyDetailedInvoices(
        api: SchoolAPI,
        billingPeriod: String,
        periodStartsAt: String,
        periodEndsAt: String,
        dueDate: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let body: [String: Any] = [
            "billing_period": billingPeriod,
            "period_starts_at": periodStartsAt,
            "period_ends_at": periodEndsAt,
            "due_date": dueDate
        ]

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/generate-monthly-detailed",
                method: "POST",
                body: body
            )

            let decoded = try? JSONDecoder().decode(MonthlyDetailedGenerationResponseDTO.self, from: data)

            if let created = decoded?.created_count {
                successMessage = "Детальные счета созданы: \(created)"
            } else {
                successMessage = "Детальные счета созданы"
            }

            await loadFilters(api: api)
            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать детальные счета: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: legal entities

    func loadLegalEntities(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/legal-entities",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(FinanceLegalEntitiesListResponseDTO.self, from: data)
            legalEntities = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить юрлица: \(error.localizedDescription)"
        }
    }

    func saveLegalEntity(
        api: SchoolAPI,
        id: Int?,
        formData: FinanceLegalEntityFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Введите название юрлица"
            isSaving = false
            return false
        }

        var body: [String: Any] = [
            "name": cleanName,
            "is_default": formData.isDefault,
            "is_active": formData.isActive
        ]

        if let value = cleanOptional(formData.inn) {
            body["inn"] = value
        }

        if let value = cleanOptional(formData.kpp) {
            body["kpp"] = value
        }

        if let value = cleanOptional(formData.bankName) {
            body["bank_name"] = value
        }

        if let value = cleanOptional(formData.bik) {
            body["bik"] = value
        }

        if let value = cleanOptional(formData.account) {
            body["account"] = value
        }

        if let value = cleanOptional(formData.correspondentAccount) {
            body["correspondent_account"] = value
        }

        do {
            let path: String
            let method: String

            if let id {
                path = "/api/v1/finance/legal-entities/\(id)"
                method = "PUT"
            } else {
                path = "/api/v1/finance/legal-entities"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = id == nil ? "Юрлицо создано" : "Юрлицо обновлено"
            await loadLegalEntities(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить юрлицо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteLegalEntity(
        api: SchoolAPI,
        id: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/legal-entities/\(id)",
                method: "DELETE"
            )

            successMessage = "Юрлицо удалено"
            await loadLegalEntities(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить юрлицо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: payer INNs

    func loadPayerInns(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/payer-inns",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(StudentPayerInnsListResponseDTO.self, from: data)
            payerInns = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить ИНН плательщиков: \(error.localizedDescription)"
        }
    }

    func savePayerInn(
        api: SchoolAPI,
        id: Int?,
        formData: StudentPayerInnFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        let payerName = formData.payerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let inn = formData.inn.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !payerName.isEmpty else {
            errorMessage = "Введите имя плательщика"
            isSaving = false
            return false
        }

        guard !inn.isEmpty else {
            errorMessage = "Введите ИНН"
            isSaving = false
            return false
        }

        var body: [String: Any] = [
            "student_id": formData.studentID,
            "payer_name": payerName,
            "inn": inn,
            "is_active": formData.isActive
        ]

        if let comment = cleanOptional(formData.comment) {
            body["comment"] = comment
        }

        do {
            let path: String
            let method: String

            if let id {
                path = "/api/v1/finance/payer-inns/\(id)"
                method = "PUT"
            } else {
                path = "/api/v1/finance/payer-inns"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = id == nil ? "ИНН плательщика добавлен" : "ИНН плательщика обновлён"
            await loadPayerInns(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить ИНН плательщика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deletePayerInn(
        api: SchoolAPI,
        id: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/payer-inns/\(id)",
                method: "DELETE"
            )

            successMessage = "ИНН плательщика удалён"
            await loadPayerInns(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить ИНН плательщика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: bank statements

    func syncBankStatementsFromGmail(api: SchoolAPI) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/bank-statements/sync-gmail",
                method: "POST"
            )

            successMessage = "Синхронизация выписок из Gmail запущена"
            await loadBankStatementImports(api: api)
            await loadBankStatementOperations(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось синхронизировать выписки: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func loadBankStatementImports(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/bank-statements/imports",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(BankStatementImportsListResponseDTO.self, from: data)
            bankStatementImports = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить импорты выписок: \(error.localizedDescription)"
        }
    }

    func loadBankStatementOperations(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/bank-statements/operations",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(BankStatementOperationsListResponseDTO.self, from: data)
            bankStatementOperations = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить операции выписок: \(error.localizedDescription)"
        }
    }

    func statusTitle(_ value: String) -> String {
        statuses.first { $0.code == value }?.title ?? value
    }

    func paymentMethodTitle(_ value: String?) -> String {
        guard let value else {
            return "Не указан"
        }

        return paymentMethods.first { $0.code == value }?.title ?? value
    }

    func studentName(for id: Int) -> String {
        students.first { $0.id == id }?.student_name ?? "Ученик \(id)"
    }

    private func decimal(from value: String) -> Decimal {
        Decimal(string: value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw FinanceError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw FinanceError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            #if DEBUG
            print("FINANCE REQUEST:", method, url.absoluteString)
            print("FINANCE BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("FINANCE REQUEST:", method, url.absoluteString)
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FinanceError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("FINANCE RESPONSE STATUS:", httpResponse.statusCode)
        print("FINANCE RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw FinanceError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FinanceError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

private struct FinanceNextMonthPayload {
    let billingPeriod: String?
    let periodStartsAt: String?
    let periodEndsAt: String?
    let dueDate: String?
}

enum FinanceError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}