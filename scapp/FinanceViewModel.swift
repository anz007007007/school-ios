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
            // Сводка по тем же ученику и периоду, что и список счетов.
            var queryItems: [URLQueryItem] = []

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if selectedPeriod != "all" {
                queryItems.append(URLQueryItem(name: "billing_period", value: selectedPeriod))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/overview",
                method: "GET",
                queryItems: queryItems
            )

            overview = try JSONDecoder().decode(FinanceOverviewResponseDTO.self, from: data)
        } catch {
            // Не блокируем экран: без сводки итоги считаются по загруженным счетам.
            overview = nil
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
                queryItems.append(URLQueryItem(name: "status_filter", value: selectedStatus))
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

            let decoded = try decodeResponse(InvoiceItemsListResponseDTO.self, from: data)
            invoiceItems = decoded.items
        } catch {
            invoiceItems = []
            errorMessage = "Не удалось загрузить детализацию счёта: \(error.localizedDescription)"
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

    /// Сервер создаёт счёт на `amountText` каждому активному ученику за следующий месяц,
    /// поэтому сумму вводит пользователь (а не берётся из случайного счёта).
    /// Уже выставленные за месяц счета сервер пропускает.
    func generateNextMonthInvoices(api: SchoolAPI, amountText: String) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        guard let amount = FinanceMoney.decimal(from: amountText), amount > 0 else {
            errorMessage = "Укажите сумму счёта больше нуля"
            return false
        }

        isSaving = true

        do {
            let body: [String: Any] = [
                "amount": FinanceMoney.plainString(amount),
                "overwrite_existing": false
            ]

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/generate-next-month",
                method: "POST",
                body: body
            )

            let decoded = try? JSONDecoder().decode(FinanceNextMonthResponseDTO.self, from: data)
            successMessage = "Создано счетов: \(decoded?.created_count ?? 0), пропущено: \(decoded?.skipped_count ?? 0)"

            await loadFilters(api: api)
            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать счета: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    /// Подпись следующего расчётного месяца («октябрь 2026») для подтверждения.
    var nextMonthLabel: String? {
        let label = filtersNextMonthDTO?.label ?? overview?.next_billing_period_label
        let period = filtersNextMonthDTO?.billing_period ?? overview?.next_billing_period

        if let label, !label.isEmpty {
            return label
        }

        return period.map { AppDateFormatter.monthYear($0) }
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

            billingSettings = try decodeResponse(BillingSettingsDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить настройки начислений: \(error.localizedDescription)"
        }
    }

    func saveBillingSettings(
        api: SchoolAPI,
        formData: BillingSettingsFormData
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        let amounts: [(field: String, title: String, value: String)] = [
            ("tuition_base_amount", "стоимость обучения", formData.tuitionBaseAmount),
            ("meal_daily_amount", "питание за день", formData.mealDailyAmount),
            ("vacation_daily_amount", "плата за день отпуска", formData.vacationDailyAmount)
        ]

        var body: [String: Any] = [:]

        for amount in amounts {
            guard let value = FinanceMoney.decimal(from: amount.value), value >= 0 else {
                errorMessage = "Укажите \(amount.title) числом не меньше нуля"
                return false
            }

            body[amount.field] = FinanceMoney.plainString(value)
        }

        guard let daysPerYear = Int(formData.vacationDaysPerYear.trimmingCharacters(in: .whitespacesAndNewlines)),
              daysPerYear >= 0 else {
            errorMessage = "Укажите количество дней отпуска в год целым числом"
            return false
        }

        guard let yearStart = AdminDateInput.iso(fromDisplay: formData.vacationYearStart) else {
            errorMessage = "Укажите начало отпускного года в формате ДД.ММ.ГГГГ"
            return false
        }

        body["vacation_days_per_year"] = daysPerYear
        body["vacation_year_start"] = yearStart
        body["missed_meal_statuses"] = MissedMealStatusOption.all
            .map(\.code)
            .filter { formData.missedMealStatuses.contains($0) }

        isSaving = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/billing-settings",
                method: "PUT",
                body: body
            )

            if let saved = try? JSONDecoder().decode(BillingSettingsDTO.self, from: data) {
                billingSettings = saved
            } else {
                await loadBillingSettings(api: api)
            }

            successMessage = "Настройки начислений сохранены"
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

        guard Self.isBillingPeriod(period) else {
            errorMessage = "Укажите расчётный месяц в формате ГГГГ-ММ"
            return
        }

        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/working-days",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "billing_period", value: period)
                ]
            )

            let decoded = try decodeResponse(WorkingDaysResponseDTO.self, from: data)
            workingDays = decoded.items.sorted { $0.day_date < $1.day_date }
            workingDaysPeriod = decoded.billing_period ?? period
        } catch {
            errorMessage = "Не удалось загрузить рабочие дни: \(error.localizedDescription)"
        }
    }

    /// Переключает день между рабочим и выходным до сохранения.
    func toggleWorkingDay(_ date: String) {
        guard let index = workingDays.firstIndex(where: { $0.day_date == date }) else {
            return
        }

        workingDays[index].is_working_day.toggle()
    }

    /// Сервер ждёт список рабочих дат месяца; остальные дни станут выходными.
    func saveWorkingDays(api: SchoolAPI) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        let period = workingDaysPeriod

        guard Self.isBillingPeriod(period), !workingDays.isEmpty else {
            errorMessage = "Сначала загрузите рабочие дни за месяц"
            return false
        }

        let body: [String: Any] = [
            "billing_period": period,
            "working_days": workingDays
                .filter(\.is_working_day)
                .map(\.day_date)
        ]

        isSaving = true

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/working-days",
                method: "PUT",
                body: body
            )

            await loadWorkingDays(api: api, billingPeriod: period)
            successMessage = "Рабочие дни сохранены"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить рабочие дни: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: vacation

    /// `vacationYearStart` — `дд.мм.гггг`; пусто — сервер берёт начало года из настроек.
    func loadStudentVacation(
        api: SchoolAPI,
        studentID: Int,
        vacationYearStart: String
    ) async {
        guard studentID != 0 else {
            errorMessage = "Выберите ученика"
            return
        }

        var queryItems: [URLQueryItem] = []
        let cleanYearStart = vacationYearStart.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanYearStart.isEmpty {
            guard let iso = AdminDateInput.iso(fromDisplay: cleanYearStart) else {
                errorMessage = "Укажите начало отпускного года в формате ДД.ММ.ГГГГ"
                return
            }

            queryItems.append(URLQueryItem(name: "vacation_year_start", value: iso))
        }

        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation",
                method: "GET",
                queryItems: queryItems
            )

            studentVacation = try decodeResponse(StudentVacationDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить отпуск ученика: \(error.localizedDescription)"
        }
    }

    /// Дни отпуска, использованные до начала учёта в приложении.
    func saveStudentVacationBalance(
        api: SchoolAPI,
        studentID: Int,
        vacationYearStart: String,
        usedDaysInitialText: String
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        guard studentID != 0 else {
            errorMessage = "Выберите ученика"
            return false
        }

        guard let yearStart = AdminDateInput.iso(fromDisplay: vacationYearStart)
                ?? studentVacation?.vacation_year_start.flatMap({ AdminDateInput.iso(fromDisplay: $0) }) else {
            errorMessage = "Укажите начало отпускного года в формате ДД.ММ.ГГГГ"
            return false
        }

        guard let usedDays = Int(usedDaysInitialText.trimmingCharacters(in: .whitespacesAndNewlines)),
              usedDays >= 0 else {
            errorMessage = "Введите количество дней целым числом"
            return false
        }

        let body: [String: Any] = [
            "vacation_year_start": yearStart,
            "used_days_initial": usedDays
        ]

        isSaving = true

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation-balance",
                method: "PUT",
                body: body
            )

            await loadStudentVacation(
                api: api,
                studentID: studentID,
                vacationYearStart: AdminDateInput.display(fromISO: yearStart)
            )
            successMessage = "Использованные дни отпуска сохранены"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить баланс отпуска: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    /// Заменяет дни отпуска ученика в месяце `billingPeriod` (ГГГГ-ММ) на `days` (ISO-даты).
    func saveStudentVacationDays(
        api: SchoolAPI,
        studentID: Int,
        billingPeriod: String,
        days: Set<String>
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        let period = billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines)

        guard studentID != 0, let bounds = Self.monthBounds(period) else {
            errorMessage = "Выберите ученика и месяц в формате ГГГГ-ММ"
            return false
        }

        let body: [String: Any] = [
            "date_from": bounds.first,
            "date_to": bounds.last,
            "vacation_days": days
                .filter { $0 >= bounds.first && $0 <= bounds.last }
                .sorted()
        ]

        let yearStart = studentVacation?.student_id == studentID
            ? AdminDateInput.display(fromISO: studentVacation?.vacation_year_start)
            : ""

        isSaving = true

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/finance/students/\(studentID)/vacation-days",
                method: "PUT",
                body: body
            )

            await loadStudentVacation(api: api, studentID: studentID, vacationYearStart: yearStart)
            successMessage = "Дни отпуска сохранены"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить дни отпуска: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin finance: monthly preview and generation

    /// `correctionPeriod` — месяц перерасчёта питания; пусто — сервер берёт предыдущий месяц.
    func previewMonthlyInvoices(
        api: SchoolAPI,
        billingPeriod: String,
        correctionPeriod: String
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        guard let body = monthlyRequestBody(billingPeriod: billingPeriod, correctionPeriod: correctionPeriod) else {
            return false
        }

        isSaving = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/invoices/preview-monthly",
                method: "POST",
                body: body
            )

            monthlyPreview = try decodeResponse(MonthlyInvoicesPreviewResponseDTO.self, from: data)
            successMessage = "Предпросмотр сформирован"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сформировать предпросмотр: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    /// Без `overwriteExisting` сервер пропускает учеников, у которых счёт за месяц уже есть.
    func generateMonthlyDetailedInvoices(
        api: SchoolAPI,
        billingPeriod: String,
        correctionPeriod: String,
        dueDate: String,
        overwriteExisting: Bool
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        errorMessage = nil
        successMessage = nil

        guard var body = monthlyRequestBody(billingPeriod: billingPeriod, correctionPeriod: correctionPeriod) else {
            return false
        }

        let cleanDueDate = dueDate.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanDueDate.isEmpty {
            guard let iso = AdminDateInput.iso(fromDisplay: cleanDueDate) else {
                errorMessage = "Срок оплаты укажите в формате ДД.ММ.ГГГГ"
                return false
            }

            body["due_date"] = iso
        }

        body["overwrite_existing"] = overwriteExisting

        isSaving = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/finance/generate-monthly-detailed",
                method: "POST",
                body: body,
                timeout: 120
            )

            let decoded = try? JSONDecoder().decode(MonthlyDetailedGenerationResponseDTO.self, from: data)
            successMessage = "Создано счетов: \(decoded?.created_count ?? 0), пропущено: \(decoded?.skipped_count ?? 0)"

            await loadFilters(api: api)
            await loadInvoices(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать счета: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func monthlyRequestBody(billingPeriod: String, correctionPeriod: String) -> [String: Any]? {
        let period = billingPeriod.trimmingCharacters(in: .whitespacesAndNewlines)
        let correction = correctionPeriod.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isBillingPeriod(period), correction.isEmpty || Self.isBillingPeriod(correction) else {
            errorMessage = "Укажите месяцы в формате ГГГГ-ММ"
            return nil
        }

        var body: [String: Any] = [
            "billing_period": period
        ]

        if !correction.isEmpty {
            body["correction_period"] = correction
        }

        return body
    }

    static func isBillingPeriod(_ value: String) -> Bool {
        monthBounds(value) != nil
    }

    /// `ГГГГ-ММ` → первый и последний день месяца в ISO.
    static func monthBounds(_ value: String) -> (first: String, last: String)? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard clean.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil,
              let first = AdminDateInput.date(fromISO: clean + "-01"),
              AdminDateInput.iso(from: first) == clean + "-01" else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)

        guard let range = calendar.range(of: .day, in: .month, for: first),
              let last = calendar.date(byAdding: .day, value: range.count - 1, to: first) else {
            return nil
        }

        return (AdminDateInput.iso(from: first), AdminDateInput.iso(from: last))
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

        guard inn.range(of: #"^\d{10}(\d{2})?$"#, options: .regularExpression) != nil else {
            errorMessage = "ИНН должен содержать 10 или 12 цифр"
            isSaving = false
            return false
        }

        // Имя плательщика необязательно. При изменении сервер не меняет ученика у связи.
        var body: [String: Any] = [
            "inn": inn,
            "is_active": formData.isActive
        ]

        if id == nil {
            body["student_id"] = formData.studentID
        }

        if !payerName.isEmpty {
            body["payer_name"] = payerName
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

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIRequestError.decodingError("сервер вернул данные в неожиданном формате")
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIRequestError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let timeout {
            request.timeoutInterval = timeout
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        #if DEBUG
        print("FINANCE REQUEST:", method, url.absoluteString)
        #endif

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIRequestError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIRequestError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("FINANCE RESPONSE STATUS:", httpResponse.statusCode)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIRequestError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}
