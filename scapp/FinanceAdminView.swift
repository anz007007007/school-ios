import SwiftUI

struct FinanceAdminView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: FinanceViewModel

    @State private var billingForm = BillingSettingsFormData()

    @State private var billingPeriod = ""
    @State private var correctionPeriod = ""
    @State private var dueDate = ""
    @State private var overwriteExisting = false

    @State private var workingDaysPeriod = ""

    @State private var vacationStudentID = 0
    @State private var vacationYearStart = ""
    @State private var vacationUsedDaysText = ""
    @State private var vacationPeriod = ""
    @State private var vacationSelectedDays: Set<String> = []

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
                "Создать счета за месяц?",
                isPresented: $isShowingGenerateConfirmation,
                titleVisibility: .visible
            ) {
                Button(overwriteExisting ? "Пересоздать счета" : "Создать счета", role: overwriteExisting ? .destructive : nil) {
                    Task {
                        _ = await viewModel.generateMonthlyDetailedInvoices(
                            api: appState.api,
                            billingPeriod: billingPeriod,
                            correctionPeriod: correctionPeriod,
                            dueDate: dueDate,
                            overwriteExisting: overwriteExisting
                        )
                    }
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                Text(overwriteExisting
                     ? "Уже выставленные за \(AppDateFormatter.monthYear(billingPeriod)) счета будут отменены и созданы заново."
                     : "Будут созданы счета за \(AppDateFormatter.monthYear(billingPeriod)) с детализацией: обучение, питание, перерасчёт и отпуск. Ученики, у которых счёт уже есть, будут пропущены.")
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
            TextField("Стоимость обучения в месяц, ₽", text: $billingForm.tuitionBaseAmount)
                .keyboardType(.decimalPad)

            TextField("Питание за день, ₽", text: $billingForm.mealDailyAmount)
                .keyboardType(.decimalPad)

            TextField("Плата за день отпуска, ₽", text: $billingForm.vacationDailyAmount)
                .keyboardType(.decimalPad)

            TextField("Дней отпуска в год", text: $billingForm.vacationDaysPerYear)
                .keyboardType(.numberPad)

            TextField("Начало отпускного года, ДД.ММ.ГГГГ", text: $billingForm.vacationYearStart)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 8) {
                Text("Не начислять питание за дни, когда ученик:")
                    .font(.subheadline)

                ForEach(MissedMealStatusOption.all, id: \.code) { option in
                    Toggle(option.title, isOn: missedMealBinding(option.code))
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)

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
            Text("Используются при предпросмотре и создании помесячных счетов: обучение, питание по рабочим дням, перерасчёт питания и отпуск.")
        }
    }

    private var monthlyGenerationSection: some View {
        Section {
            TextField("Расчётный месяц, ГГГГ-ММ", text: $billingPeriod)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Месяц перерасчёта питания, ГГГГ-ММ", text: $correctionPeriod)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Срок оплаты, ДД.ММ.ГГГГ", text: $dueDate)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle(isOn: $overwriteExisting) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Перезаписать счета")
                    Text("Пересоздать уже выставленные счета за этот месяц")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    _ = await viewModel.previewMonthlyInvoices(
                        api: appState.api,
                        billingPeriod: billingPeriod,
                        correctionPeriod: correctionPeriod
                    )
                }
            } label: {
                Label("Предпросмотр начислений", systemImage: "eye.fill")
            }
            .disabled(viewModel.isSaving)

            Button {
                isShowingGenerateConfirmation = true
            } label: {
                Label("Создать счета", systemImage: "doc.badge.plus")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Помесячные счета")
        } footer: {
            Text("Месяц перерасчёта по умолчанию — предыдущий. Срок оплаты можно не указывать. Без перезаписи ученики, у которых счёт за месяц уже есть, пропускаются.")
        }
    }

    private var monthlyPreviewSection: some View {
        Section("Предпросмотр начислений") {
            if let preview = viewModel.monthlyPreview {
                LabeledContent("Месяц", value: AppDateFormatter.monthYear(preview.billing_period ?? billingPeriod))

                if let correction = preview.correction_period, !correction.isEmpty {
                    LabeledContent("Перерасчёт питания за", value: AppDateFormatter.monthYear(correction))
                }

                LabeledContent("Счетов", value: "\(preview.items.count)")
                LabeledContent("Итого", value: FinanceMoney.plainString(preview.totalAmount))

                ForEach(preview.items) { item in
                    MonthlyPreviewItemRow(item: item)
                }
            } else {
                Text("Предпросмотр ещё не сформирован.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workingDaysSection: some View {
        Section {
            TextField("Расчётный месяц, ГГГГ-ММ", text: $workingDaysPeriod)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task {
                    await viewModel.loadWorkingDays(
                        api: appState.api,
                        billingPeriod: workingDaysPeriod
                    )
                }
            } label: {
                Label("Загрузить рабочие дни", systemImage: "calendar")
            }

            if !viewModel.workingDays.isEmpty,
               FinanceViewModel.isBillingPeriod(viewModel.workingDaysPeriod) {
                LabeledContent("Месяц", value: AppDateFormatter.monthYear(viewModel.workingDaysPeriod))
                LabeledContent("Рабочих дней", value: "\(viewModel.workingDays.filter(\.is_working_day).count)")

                FinanceMonthDaysGrid(
                    period: viewModel.workingDaysPeriod,
                    selectedDates: Set(viewModel.workingDays.filter(\.is_working_day).map(\.day_date)),
                    isEnabled: !viewModel.isSaving,
                    onToggle: { date in
                        viewModel.toggleWorkingDay(date)
                    }
                )
                .padding(.vertical, 4)

                Button {
                    Task {
                        _ = await viewModel.saveWorkingDays(api: appState.api)
                    }
                } label: {
                    Label("Сохранить рабочие дни", systemImage: "checkmark.circle.fill")
                }
                .disabled(viewModel.isSaving)
            }
        } header: {
            Text("Рабочие дни")
        } footer: {
            Text("Нажмите на день, чтобы сделать его рабочим или выходным. Питание начисляется за рабочие дни.")
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

            TextField("Начало отпускного года, ДД.ММ.ГГГГ", text: $vacationYearStart)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task {
                    await viewModel.loadStudentVacation(
                        api: appState.api,
                        studentID: vacationStudentID,
                        vacationYearStart: vacationYearStart
                    )

                    applyLoadedVacation()
                }
            } label: {
                Label("Загрузить отпуск ученика", systemImage: "sun.max.fill")
            }

            if let vacation = viewModel.studentVacation, vacation.student_id == vacationStudentID {
                LabeledContent("Ученик", value: vacation.student_name ?? viewModel.studentName(for: vacation.student_id))
                LabeledContent("Отпускной год с", value: AppDateFormatter.date(vacation.vacation_year_start))
                LabeledContent("Лимит в год", value: vacation.vacation_days_per_year.map(String.init) ?? "—")
                LabeledContent("Использовано", value: "\(vacation.used_days_total ?? 0)")
                LabeledContent("Осталось", value: "\(vacation.remaining_days ?? 0)")

                TextField("Дней отпуска, использованных ранее", text: $vacationUsedDaysText)
                    .keyboardType(.numberPad)

                Button {
                    Task {
                        _ = await viewModel.saveStudentVacationBalance(
                            api: appState.api,
                            studentID: vacationStudentID,
                            vacationYearStart: vacationYearStart,
                            usedDaysInitialText: vacationUsedDaysText
                        )

                        applyLoadedVacation()
                    }
                } label: {
                    Label("Сохранить использованные дни", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.isSaving)

                TextField("Месяц отпуска, ГГГГ-ММ", text: $vacationPeriod)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: vacationPeriod) {
                        vacationSelectedDays = Set(vacation.days)
                    }

                if FinanceViewModel.isBillingPeriod(vacationPeriod) {
                    LabeledContent("Отмечено в месяце", value: "\(selectedVacationDaysInPeriod.count)")

                    FinanceMonthDaysGrid(
                        period: vacationPeriod,
                        selectedDates: vacationSelectedDays,
                        isEnabled: !viewModel.isSaving,
                        onToggle: { date in
                            if vacationSelectedDays.contains(date) {
                                vacationSelectedDays.remove(date)
                            } else {
                                vacationSelectedDays.insert(date)
                            }
                        }
                    )
                    .padding(.vertical, 4)

                    Button {
                        Task {
                            _ = await viewModel.saveStudentVacationDays(
                                api: appState.api,
                                studentID: vacationStudentID,
                                billingPeriod: vacationPeriod,
                                days: vacationSelectedDays
                            )

                            applyLoadedVacation()
                        }
                    } label: {
                        Label("Сохранить дни отпуска", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(viewModel.isSaving)
                } else {
                    Text("Укажите месяц в формате ГГГГ-ММ, чтобы отметить дни отпуска.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Отпуска учеников")
        } footer: {
            Text("Пустое начало года — берётся из настроек начислений. Дни отпуска сверх годового лимита оплачиваются полностью.")
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
                        Text(item.payer_name.flatMap { $0.isEmpty ? nil : $0 } ?? "ИНН \(item.inn)")
                            .font(.headline)

                        if item.payer_name?.isEmpty == false {
                            Text("ИНН: \(item.inn)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.student_name ?? viewModel.studentName(for: item.student_id))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if item.is_active == false {
                            Text("Не активен")
                                .font(.caption)
                                .foregroundStyle(.orange)
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

        let nextPeriod = viewModel.filtersNextMonthDTO?.billing_period
            ?? viewModel.overview?.next_billing_period
            ?? ""

        if billingPeriod.isEmpty {
            billingPeriod = nextPeriod
        }

        if workingDaysPeriod.isEmpty {
            workingDaysPeriod = nextPeriod
        }

        if vacationPeriod.isEmpty {
            vacationPeriod = nextPeriod
        }

        if vacationYearStart.isEmpty {
            vacationYearStart = AdminDateInput.display(fromISO: viewModel.billingSettings?.vacation_year_start)
        }
    }

    private func applyLoadedVacation() {
        guard let vacation = viewModel.studentVacation, vacation.student_id == vacationStudentID else {
            return
        }

        vacationUsedDaysText = vacation.used_days_initial.map(String.init) ?? "0"
        vacationSelectedDays = Set(vacation.days)

        let loadedYearStart = AdminDateInput.display(fromISO: vacation.vacation_year_start)

        if !loadedYearStart.isEmpty {
            vacationYearStart = loadedYearStart
        }
    }

    private var selectedVacationDaysInPeriod: [String] {
        guard let bounds = FinanceViewModel.monthBounds(vacationPeriod) else {
            return []
        }

        return vacationSelectedDays.filter { $0 >= bounds.first && $0 <= bounds.last }.sorted()
    }

    private func missedMealBinding(_ code: String) -> Binding<Bool> {
        Binding(
            get: { billingForm.missedMealStatuses.contains(code) },
            set: { isOn in
                if isOn {
                    billingForm.missedMealStatuses.insert(code)
                } else {
                    billingForm.missedMealStatuses.remove(code)
                }
            }
        )
    }
}

private struct MonthlyPreviewItemRow: View {
    let item: MonthlyInvoicePreviewItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.student_name)
                        .font(.headline)

                    if let className = item.class_name, !className.isEmpty {
                        Text(className)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(item.total_amount)
                    .font(.headline)
            }

            Group {
                Text("Обучение: \(item.tuition_amount ?? "—")")
                Text("Питание: \(item.meal_days ?? 0) дн. × \(item.meal_daily_amount ?? "—") = \(item.meal_amount ?? "—")")

                if (item.missed_meal_days ?? 0) > 0 {
                    Text("Перерасчёт питания: \(item.missed_meal_days ?? 0) дн. = \(item.meal_correction_amount ?? "—")")
                }

                if (item.vacation_days ?? 0) > 0 {
                    Text("Отпуск: \(item.vacation_chargeable_days ?? 0) дн. × \(item.vacation_daily_amount ?? "—") = \(item.vacation_amount ?? "—")")

                    if (item.vacation_over_limit_days ?? 0) > 0 {
                        Text("Сверх лимита: \(item.vacation_over_limit_days ?? 0) дн.")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// Сетка дней месяца `period` (ГГГГ-ММ) по неделям с понедельника; отмеченные дни — ISO-даты.
private struct FinanceMonthDaysGrid: View {
    let period: String
    let selectedDates: Set<String>
    let isEnabled: Bool
    let onToggle: (String) -> Void

    private let weekdayTitles = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdayTitles, id: \.self) { title in
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let cell {
                    let isSelected = selectedDates.contains(cell.iso)

                    Button {
                        onToggle(cell.iso)
                    } label: {
                        Text("\(cell.day)")
                            .font(.callout)
                            .fontWeight(isSelected ? .bold : .regular)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(isSelected ? AppTheme.primaryDark : AppTheme.cardSoft)
                            .foregroundStyle(isSelected ? Color.white : AppTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                } else {
                    Color.clear
                        .frame(minHeight: 34)
                }
            }
        }
    }

    private var cells: [(day: Int, iso: String)?] {
        guard let bounds = FinanceViewModel.monthBounds(period),
              let first = AdminDateInput.date(fromISO: bounds.first),
              let last = AdminDateInput.date(fromISO: bounds.last) else {
            return []
        }

        let calendar = Calendar(identifier: .gregorian)
        // weekday: 1 — воскресенье … 7 — суббота → сдвиг от понедельника.
        let leadingBlanks = (calendar.component(.weekday, from: first) + 5) % 7
        let dayCount = calendar.component(.day, from: last)

        var result: [(day: Int, iso: String)?] = Array(repeating: nil, count: leadingBlanks)

        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: first) {
                result.append((offset + 1, AdminDateInput.iso(from: date)))
            }
        }

        return result
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
                    if item == nil {
                        Picker("Ученик", selection: $formData.studentID) {
                            Text("Выберите ученика").tag(0)

                            ForEach(students) { student in
                                Text(student.student_name).tag(student.id)
                            }
                        }
                    } else {
                        // Сервер не меняет ученика у существующей связи.
                        LabeledContent(
                            "Ученик",
                            value: item?.student_name
                                ?? students.first { $0.id == formData.studentID }?.student_name
                                ?? "—"
                        )
                    }

                    TextField("Имя плательщика (необязательно)", text: $formData.payerName)
                    TextField("ИНН (10 или 12 цифр)", text: $formData.inn)
                        .keyboardType(.numberPad)
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