import SwiftUI

struct FinanceAdminView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: FinanceViewModel

    @State private var billingForm = BillingSettingsFormData()

    @State private var billingPeriod = ""
    @State private var periodStartsAt = ""
    @State private var periodEndsAt = ""
    @State private var dueDate = ""

    @State private var workingDaysDraft: [WorkingDayDTO] = []
    @State private var newWorkingDayDate = ""
    @State private var newWorkingDayComment = ""
    @State private var newWorkingDayIsWorking = true

    @State private var vacationStudentID = 0
    @State private var vacationPeriod = ""
    @State private var vacationBalanceText = ""
    @State private var vacationDaysDraft: [StudentVacationDayDTO] = []
    @State private var newVacationDate = ""
    @State private var newVacationComment = ""

    @State private var editingLegalEntity: FinanceLegalEntityDTO?
    @State private var isShowingLegalEntityForm = false

    @State private var editingPayerInn: StudentPayerInnDTO?
    @State private var isShowingPayerInnForm = false

    @State private var isShowingGenerateConfirmation = false
    @State private var legalEntityToDelete: FinanceLegalEntityDTO?
    @State private var payerInnToDelete: StudentPayerInnDTO?

    var body: some View {
        NavigationStack {
            List {
                messagesSection
                billingSettingsSection
                monthlyGenerationSection
                monthlyPreviewSection
                workingDaysSection
                vacationSection
                legalEntitiesSection
                payerInnsSection
                bankStatementsSection
            }
            .navigationTitle("Админка финансов")
            .refreshable {
                await reload()
            }
            .task {
                if viewModel.billingSettings == nil {
                    await reload()
                }

                prepareForms()
            }
            .onChange(of: viewModel.billingSettings) {
                billingForm = BillingSettingsFormData(settings: viewModel.billingSettings)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await reload()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $isShowingLegalEntityForm) {
                FinanceLegalEntityFormView(
                    entity: editingLegalEntity,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        Task {
                            let saved = await viewModel.saveLegalEntity(
                                api: appState.api,
                                id: editingLegalEntity?.id,
                                formData: formData
                            )

                            if saved {
                                editingLegalEntity = nil
                                isShowingLegalEntityForm = false
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingPayerInnForm) {
                StudentPayerInnFormView(
                    item: editingPayerInn,
                    students: viewModel.students,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        Task {
                            let saved = await viewModel.savePayerInn(
                                api: appState.api,
                                id: editingPayerInn?.id,
                                formData: formData
                            )

                            if saved {
                                editingPayerInn = nil
                                isShowingPayerInnForm = false
                            }
                        }
                    }
                )
            }
            .confirmationDialog(
                "Создать детальные счета?",
                isPresented: $isShowingGenerateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Создать счета") {
                    Task {
                        _ = await viewModel.generateMonthlyDetailedInvoices(
                            api: appState.api,
                            billingPeriod: billingPeriod,
                            periodStartsAt: periodStartsAt,
                            periodEndsAt: periodEndsAt,
                            dueDate: dueDate
                        )
                    }
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Будут созданы счета с детализацией начислений, рабочих дней и отпусков.")
            }
            .confirmationDialog(
                "Удалить юрлицо?",
                isPresented: Binding(
                    get: { legalEntityToDelete != nil },
                    set: { if !$0 { legalEntityToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let legalEntityToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deleteLegalEntity(
                            api: appState.api,
                            id: legalEntityToDelete.id
                        )

                        self.legalEntityToDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    legalEntityToDelete = nil
                }
            }
            .confirmationDialog(
                "Удалить ИНН плательщика?",
                isPresented: Binding(
                    get: { payerInnToDelete != nil },
                    set: { if !$0 { payerInnToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let payerInnToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deletePayerInn(
                            api: appState.api,
                            id: payerInnToDelete.id
                        )

                        self.payerInnToDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    payerInnToDelete = nil
                }
            }
        }
    }

    private var messagesSection: some View {
        Group {
            if viewModel.isLoadingAdminFinance {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка финансовой админки...")
                        Spacer()
                    }
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var billingSettingsSection: some View {
        Section {
            TextField("Месячная стоимость", text: $billingForm.monthlyAmount)
                .keyboardType(.decimalPad)

            TextField("Шаблон названия счёта", text: $billingForm.invoiceTitleTemplate)

            TextField("Шаблон описания", text: $billingForm.invoiceDescriptionTemplate, axis: .vertical)
                .lineLimit(2...5)

            TextField("День оплаты", text: $billingForm.dueDay)
                .keyboardType(.numberPad)

            Toggle("Учитывать отпускные дни", isOn: $billingForm.vacationDiscountEnabled)

            if billingForm.vacationDiscountEnabled {
                TextField("Ставка перерасчёта за день", text: $billingForm.vacationDailyRate)
                    .keyboardType(.decimalPad)

                TextField("Мин. рабочих дней для полной оплаты", text: $billingForm.minWorkingDaysForFullCharge)
                    .keyboardType(.numberPad)
            }

            Button {
                Task {
                    _ = await viewModel.saveBillingSettings(
                        api: appState.api,
                        formData: billingForm
                    )
                }
            } label: {
                Label("Сохранить настройки начислений", systemImage: "checkmark.circle.fill")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Настройки начислений")
        } footer: {
            Text("Эти настройки используются при предпросмотре и генерации детальных месячных счетов.")
        }
    }

    private var monthlyGenerationSection: some View {
        Section {
            TextField("Период, например 2026-06", text: $billingPeriod)
                .textInputAutocapitalization(.never)

            TextField("Начало периода, YYYY-MM-DD", text: $periodStartsAt)
                .textInputAutocapitalization(.never)

            TextField("Конец периода, YYYY-MM-DD", text: $periodEndsAt)
                .textInputAutocapitalization(.never)

            TextField("Срок оплаты, YYYY-MM-DD", text: $dueDate)
                .textInputAutocapitalization(.never)

            Button {
                Task {
                    _ = await viewModel.previewMonthlyInvoices(
                        api: appState.api,
                        billingPeriod: billingPeriod,
                        periodStartsAt: periodStartsAt,
                        periodEndsAt: periodEndsAt,
                        dueDate: dueDate
                    )
                }
            } label: {
                Label("Предпросмотр начислений", systemImage: "eye.fill")
            }
            .disabled(viewModel.isSaving)

            Button {
                isShowingGenerateConfirmation = true
            } label: {
                Label("Создать детальные счета", systemImage: "doc.badge.plus")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Месячные начисления")
        } footer: {
            Text("Сначала сделайте предпросмотр, проверьте суммы, потом создавайте счета.")
        }
    }

    private var monthlyPreviewSection: some View {
        Section("Предпросмотр начислений") {
            if let preview = viewModel.monthlyPreview {
                LabeledContent("Период", value: AppDateFormatter.monthYear(preview.billing_period ?? billingPeriod))
                LabeledContent("Счетов", value: "\(preview.total_count ?? preview.items.count)")
                LabeledContent("Итого", value: preview.total_amount ?? "—")

                ForEach(preview.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.student_name)
                                    .font(.headline)

                                if let className = item.class_name {
                                    Text(className)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(item.amount)
                                .font(.headline)
                        }

                        HStack {
                            if let base = item.base_amount {
                                Label("База: \(base)", systemImage: "sum")
                            }

                            if let discount = item.discount_amount {
                                Label("Скидка: \(discount)", systemImage: "minus.circle")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack {
                            if let workingDays = item.working_days {
                                Label("Раб. дней: \(workingDays)", systemImage: "calendar")
                            }

                            if let vacationDays = item.vacation_days {
                                Label("Отпуск: \(vacationDays)", systemImage: "sun.max")
                            }

                            if let payableDays = item.payable_days {
                                Label("К оплате: \(payableDays)", systemImage: "checkmark.circle")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let comment = item.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Text("Предпросмотр ещё не сформирован.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workingDaysSection: some View {
        Section {
            TextField("Период для рабочих дней", text: $billingPeriod)
                .textInputAutocapitalization(.never)

            Button {
                Task {
                    await viewModel.loadWorkingDays(
                        api: appState.api,
                        billingPeriod: billingPeriod
                    )

                    workingDaysDraft = viewModel.workingDays
                }
            } label: {
                Label("Загрузить рабочие дни", systemImage: "calendar")
            }

            if !workingDaysDraft.isEmpty {
                ForEach(workingDaysDraft) { day in
                    WorkingDayDraftRow(
                        day: day,
                        onToggle: {
                            toggleWorkingDay(day)
                        },
                        onDelete: {
                            workingDaysDraft.removeAll { $0.id == day.id }
                        }
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Добавить день")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("Дата, YYYY-MM-DD", text: $newWorkingDayDate)
                    .textInputAutocapitalization(.never)

                Toggle("Рабочий день", isOn: $newWorkingDayIsWorking)

                TextField("Комментарий", text: $newWorkingDayComment)

                Button {
                    addWorkingDay()
                } label: {
                    Label("Добавить день", systemImage: "plus.circle")
                }
            }

            Button {
                Task {
                    _ = await viewModel.saveWorkingDays(
                        api: appState.api,
                        billingPeriod: billingPeriod,
                        days: workingDaysDraft
                    )
                }
            } label: {
                Label("Сохранить рабочие дни", systemImage: "checkmark.circle.fill")
            }
            .disabled(viewModel.isSaving || workingDaysDraft.isEmpty)
        } header: {
            Text("Рабочие дни")
        } footer: {
            Text("Рабочие дни влияют на расчёт детальных счетов и отпускных перерасчётов.")
        }
    }

    private var vacationSection: some View {
        Section {
            Picker("Ученик", selection: $vacationStudentID) {
                Text("Выберите ученика").tag(0)

                ForEach(viewModel.students) { student in
                    Text(student.student_name).tag(student.id)
                }
            }

            TextField("Период отпуска, например 2026-06", text: $vacationPeriod)
                .textInputAutocapitalization(.never)

            Button {
                Task {
                    await viewModel.loadStudentVacation(
                        api: appState.api,
                        studentID: vacationStudentID,
                        billingPeriod: vacationPeriod
                    )

                    vacationBalanceText = viewModel.studentVacation?.balance_days.map(String.init) ?? ""
                    vacationDaysDraft = viewModel.studentVacation?.vacation_days ?? []
                }
            } label: {
                Label("Загрузить отпуск ученика", systemImage: "sun.max.fill")
            }

            if let vacation = viewModel.studentVacation {
                LabeledContent("Ученик", value: vacation.student_name ?? viewModel.studentName(for: vacation.student_id))
                LabeledContent("Баланс дней", value: vacation.balance_days.map(String.init) ?? "—")
                LabeledContent("Использовано", value: vacation.used_days.map(String.init) ?? "—")
                LabeledContent("Доступно", value: vacation.available_days.map(String.init) ?? "—")
            }

            TextField("Баланс отпускных дней", text: $vacationBalanceText)
                .keyboardType(.numberPad)

            Button {
                Task {
                    _ = await viewModel.saveStudentVacationBalance(
                        api: appState.api,
                        studentID: vacationStudentID,
                        billingPeriod: vacationPeriod,
                        balanceDays: Int(vacationBalanceText) ?? 0
                    )
                }
            } label: {
                Label("Сохранить баланс", systemImage: "checkmark.circle")
            }

            if !vacationDaysDraft.isEmpty {
                ForEach(vacationDaysDraft) { day in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(AppDateFormatter.date(day.date))
                                .font(.headline)

                            if let comment = day.comment, !comment.isEmpty {
                                Text(comment)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            vacationDaysDraft.removeAll { $0.id == day.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Добавить день отпуска")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("Дата, YYYY-MM-DD", text: $newVacationDate)
                    .textInputAutocapitalization(.never)

                TextField("Комментарий", text: $newVacationComment)

                Button {
                    addVacationDay()
                } label: {
                    Label("Добавить день отпуска", systemImage: "plus.circle")
                }
            }

            Button {
                Task {
                    _ = await viewModel.saveStudentVacationDays(
                        api: appState.api,
                        studentID: vacationStudentID,
                        billingPeriod: vacationPeriod,
                        days: vacationDaysDraft
                    )
                }
            } label: {
                Label("Сохранить дни отпуска", systemImage: "checkmark.circle.fill")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Отпуска учеников")
        } footer: {
            Text("Отпускные дни будут отображаться родителям в детализации начислений.")
        }
    }

    private var legalEntitiesSection: some View {
        Section {
            if viewModel.legalEntities.isEmpty {
                Text("Юрлица не добавлены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.legalEntities) { entity in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entity.name)
                                .font(.headline)

                            if entity.is_default == true {
                                Text("По умолчанию")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }

                        if let inn = entity.inn {
                            Text("ИНН: \(inn)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let bank = entity.bank_name {
                            Text(bank)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            legalEntityToDelete = entity
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }

                        Button {
                            editingLegalEntity = entity
                            isShowingLegalEntityForm = true
                        } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }

            Button {
                editingLegalEntity = nil
                isShowingLegalEntityForm = true
            } label: {
                Label("Добавить юрлицо", systemImage: "plus")
            }
        } header: {
            Text("Юрлица")
        }
    }

    private var payerInnsSection: some View {
        Section {
            if viewModel.payerInns.isEmpty {
                Text("ИНН плательщиков не добавлены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.payerInns) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.payer_name)
                            .font(.headline)

                        Text("ИНН: \(item.inn)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(item.student_name ?? viewModel.studentName(for: item.student_id))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let comment = item.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            payerInnToDelete = item
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }

                        Button {
                            editingPayerInn = item
                            isShowingPayerInnForm = true
                        } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }

            Button {
                editingPayerInn = nil
                isShowingPayerInnForm = true
            } label: {
                Label("Добавить ИНН плательщика", systemImage: "plus")
            }
        } header: {
            Text("ИНН плательщиков")
        } footer: {
            Text("Используется для сопоставления банковских платежей с учениками и счетами.")
        }
    }

    private var bankStatementsSection: some View {
        Section {
            Button {
                Task {
                    _ = await viewModel.syncBankStatementsFromGmail(api: appState.api)
                }
            } label: {
                Label("Синхронизировать выписки из Gmail", systemImage: "envelope.badge.fill")
            }
            .disabled(viewModel.isSaving)

            Button {
                Task {
                    await viewModel.loadBankStatementImports(api: appState.api)
                    await viewModel.loadBankStatementOperations(api: appState.api)
                }
            } label: {
                Label("Обновить выписки", systemImage: "arrow.clockwise")
            }

            if !viewModel.bankStatementImports.isEmpty {
                DisclosureGroup("Импорты: \(viewModel.bankStatementImports.count)") {
                    ForEach(viewModel.bankStatementImports) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.filename ?? "Импорт #\(item.id)")
                                .font(.headline)

                            HStack {
                                Text(item.status ?? "—")
                                Text("Операций: \(item.operations_count ?? 0)")
                                Text("Сопоставлено: \(item.matched_count ?? 0)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let message = item.message, !message.isEmpty {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !viewModel.bankStatementOperations.isEmpty {
                DisclosureGroup("Операции: \(viewModel.bankStatementOperations.count)") {
                    ForEach(viewModel.bankStatementOperations) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.amount)
                                    .font(.headline)

                                Spacer()

                                Text(item.status ?? "—")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let date = item.operation_date {
                                Text(AppDateFormatter.date(date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let payer = item.payer_name {
                                Text(payer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let student = item.matched_student_name {
                                Label(student, systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            if let purpose = item.payment_purpose {
                                Text(purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } header: {
            Text("Банковские выписки")
        } footer: {
            Text("Загрузка файла выписки требует multipart upload. Здесь уже добавлена синхронизация из Gmail и просмотр импортов/операций.")
        }
    }

    private func reload() async {
        await viewModel.loadFilters(api: appState.api)
        await viewModel.loadFinanceAdminData(api: appState.api)
        prepareForms()
    }

    private func prepareForms() {
        billingForm = BillingSettingsFormData(settings: viewModel.billingSettings)

        if billingPeriod.isEmpty {
            billingPeriod = viewModel.filtersNextMonthDTO?.billing_period
                ?? viewModel.overview?.next_billing_period
                ?? ""
        }

        if periodStartsAt.isEmpty {
            periodStartsAt = viewModel.filtersNextMonthDTO?.period_starts_at
                ?? viewModel.overview?.next_period_starts_at
                ?? ""
        }

        if periodEndsAt.isEmpty {
            periodEndsAt = viewModel.filtersNextMonthDTO?.period_ends_at
                ?? viewModel.overview?.next_period_ends_at
                ?? ""
        }

        if dueDate.isEmpty {
            dueDate = viewModel.filtersNextMonthDTO?.due_date
                ?? viewModel.overview?.next_due_date
                ?? ""
        }

        if vacationPeriod.isEmpty {
            vacationPeriod = billingPeriod
        }
    }

    private func addWorkingDay() {
        let date = newWorkingDayDate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !date.isEmpty else {
            return
        }

        workingDaysDraft.removeAll { $0.date == date }

        workingDaysDraft.append(
            WorkingDayDTO(
                date: date,
                is_working: newWorkingDayIsWorking,
                comment: newWorkingDayComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newWorkingDayComment
            )
        )

        workingDaysDraft.sort { $0.date < $1.date }

        newWorkingDayDate = ""
        newWorkingDayComment = ""
        newWorkingDayIsWorking = true
    }

    private func toggleWorkingDay(_ day: WorkingDayDTO) {
        guard let index = workingDaysDraft.firstIndex(where: { $0.id == day.id }) else {
            return
        }

        workingDaysDraft[index] = WorkingDayDTO(
            date: day.date,
            is_working: !day.is_working,
            comment: day.comment
        )
    }

    private func addVacationDay() {
        let date = newVacationDate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !date.isEmpty else {
            return
        }

        vacationDaysDraft.removeAll { $0.date == date }

        vacationDaysDraft.append(
            StudentVacationDayDTO(
                date: date,
                comment: newVacationComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newVacationComment
            )
        )

        vacationDaysDraft.sort { $0.date < $1.date }

        newVacationDate = ""
        newVacationComment = ""
    }
}

private struct WorkingDayDraftRow: View {
    let day: WorkingDayDTO
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateFormatter.date(day.date))
                    .font(.headline)

                Text(day.is_working ? "Рабочий день" : "Выходной")
                    .font(.caption)
                    .foregroundStyle(day.is_working ? .green : .orange)

                if let comment = day.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onToggle()
            } label: {
                Image(systemName: day.is_working ? "checkmark.circle.fill" : "xmark.circle.fill")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
    }
}

struct FinanceLegalEntityFormView: View {
    @Environment(\.dismiss) private var dismiss

    let entity: FinanceLegalEntityDTO?
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (FinanceLegalEntityFormData) -> Void

    @State private var formData: FinanceLegalEntityFormData

    init(
        entity: FinanceLegalEntityDTO?,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (FinanceLegalEntityFormData) -> Void
    ) {
        self.entity = entity
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        _formData = State(initialValue: entity.map(FinanceLegalEntityFormData.init(entity:)) ?? FinanceLegalEntityFormData())
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Основное") {
                    TextField("Название", text: $formData.name)
                    TextField("ИНН", text: $formData.inn)
                    TextField("КПП", text: $formData.kpp)
                    Toggle("По умолчанию", isOn: $formData.isDefault)
                    Toggle("Активно", isOn: $formData.isActive)
                }

                Section("Банк") {
                    TextField("Банк", text: $formData.bankName)
                    TextField("БИК", text: $formData.bik)
                    TextField("Расчётный счёт", text: $formData.account)
                    TextField("Корр. счёт", text: $formData.correspondentAccount)
                }
            }
            .navigationTitle(entity == nil ? "Новое юрлицо" : "Юрлицо")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(formData)
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

struct StudentPayerInnFormView: View {
    @Environment(\.dismiss) private var dismiss

    let item: StudentPayerInnDTO?
    let students: [FinanceStudentFilterDTO]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (StudentPayerInnFormData) -> Void

    @State private var formData: StudentPayerInnFormData

    init(
        item: StudentPayerInnDTO?,
        students: [FinanceStudentFilterDTO],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (StudentPayerInnFormData) -> Void
    ) {
        self.item = item
        self.students = students
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        _formData = State(initialValue: item.map(StudentPayerInnFormData.init(item:)) ?? StudentPayerInnFormData())
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Плательщик") {
                    Picker("Ученик", selection: $formData.studentID) {
                        Text("Выберите ученика").tag(0)

                        ForEach(students) { student in
                            Text(student.student_name).tag(student.id)
                        }
                    }

                    TextField("ФИО плательщика", text: $formData.payerName)
                    TextField("ИНН", text: $formData.inn)
                    TextField("Комментарий", text: $formData.comment, axis: .vertical)
                        .lineLimit(2...5)
                    Toggle("Активно", isOn: $formData.isActive)
                }
            }
            .navigationTitle(item == nil ? "Новый ИНН" : "ИНН плательщика")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(formData)
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}