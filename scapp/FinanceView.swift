import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = FinanceViewModel()

    @State private var selectedInvoice: InvoiceDTO?
    @State private var editingInvoice: InvoiceDTO?
    @State private var invoiceToCancel: InvoiceDTO?

    @State private var editingPayment: PaymentDTO?
    @State private var paymentToDelete: PaymentDTO?

    @State private var isShowingCreateInvoice = false
    @State private var isShowingCreatePayment = false
    @State private var isShowingCancelConfirmation = false
    @State private var isShowingDeletePaymentConfirmation = false
    @State private var isShowingGenerateConfirmation = false
    @State private var isShowingFinanceAdmin = false
    @State private var nextMonthAmount = ""

    var body: some View {
        NavigationStack {
            Group {
                if !appState.canUseFinance {
                    unavailableView
                } else {
                    financeList
                }
            }
            .navigationTitle("Финансы")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Поиск счетов")
            .preferredColorScheme(.light)
            .refreshable {
                if appState.canUseFinance {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .task {
                if appState.canUseFinance {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .onChange(of: appState.tabReselectToken[.finance]) {
                guard appState.canUseFinance else {
                    return
                }

                Task {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if appState.canUseFinance && appState.canManageFinance {
                        Menu {
                            Button {
                                isShowingCreateInvoice = true
                            } label: {
                                Label("Создать счёт", systemImage: "doc.badge.plus")
                            }

                            Button {
                                isShowingCreatePayment = true
                            } label: {
                                Label("Добавить платёж", systemImage: "creditcard.fill")
                            }
                            .disabled(viewModel.selectedInvoice == nil)

                            Button {
                                isShowingGenerateConfirmation = true
                            } label: {
                                Label("Счета на следующий месяц", systemImage: "calendar.badge.plus")
                            }

                            Button {
                                isShowingFinanceAdmin = true
                            } label: {
                                Label("Админка финансов", systemImage: "gearshape.2.fill")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    if appState.canUseFinance {
                        Button {
                            Task {
                                await viewModel.loadInitialData(api: appState.api)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingFinanceAdmin) {
                FinanceAdminView(viewModel: viewModel)
                    .environmentObject(appState)
            }
            .sheet(item: $selectedInvoice) { invoice in
                InvoiceDetailView(
                    invoice: invoice,
                    statusTitle: viewModel.statusTitle(invoice.status),
                    invoiceItems: viewModel.invoiceItems,
                    canManage: appState.canManageFinance,
                    onEdit: {
                        selectedInvoice = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            editingInvoice = invoice
                        }
                    },
                    onCancel: {
                        selectedInvoice = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            invoiceToCancel = invoice
                            isShowingCancelConfirmation = true
                        }
                    },
                    onPayments: {
                        selectedInvoice = nil

                        Task {
                            await viewModel.loadPayments(
                                api: appState.api,
                                invoiceID: invoice.id
                            )
                        }
                    }
                )
                .task {
                    await viewModel.loadInvoiceItems(
                        api: appState.api,
                        invoiceID: invoice.id
                    )
                }
            }
            .sheet(isPresented: $isShowingCreateInvoice) {
                InvoiceFormView(
                    mode: .create,
                    invoice: nil,
                    students: viewModel.students,
                    periods: viewModel.periods,
                    statuses: viewModel.statuses,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = InvoiceFormData(
                            studentID: formData.studentID,
                            title: String(formData.title),
                            description: String(formData.description),
                            amount: String(formData.amount),
                            dueDate: String(formData.dueDate),
                            period: String(formData.period),
                            status: String(formData.status)
                        )

                        Task { @MainActor in
                            let saved = await viewModel.createInvoice(
                                api: appState.api,
                                formData: safeFormData
                            )

                            if saved {
                                isShowingCreateInvoice = false
                            }
                        }
                    }
                )
            }
            .sheet(item: $editingInvoice) { invoice in
                InvoiceFormView(
                    mode: .edit,
                    invoice: invoice,
                    students: viewModel.students,
                    periods: viewModel.periods,
                    statuses: viewModel.statuses,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = InvoiceFormData(
                            studentID: formData.studentID,
                            title: String(formData.title),
                            description: String(formData.description),
                            amount: String(formData.amount),
                            dueDate: String(formData.dueDate),
                            period: String(formData.period),
                            status: String(formData.status)
                        )

                        Task { @MainActor in
                            let saved = await viewModel.updateInvoice(
                                api: appState.api,
                                invoiceID: invoice.id,
                                formData: safeFormData
                            )

                            if saved {
                                editingInvoice = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingCreatePayment) {
                if let invoice = viewModel.selectedInvoice {
                    PaymentFormView(
                        mode: .create,
                        payment: nil,
                        invoice: invoice,
                        paymentMethods: viewModel.paymentMethods,
                        isSaving: viewModel.isSaving,
                        errorMessage: viewModel.errorMessage,
                        onSave: { formData in
                            let safeFormData = PaymentFormData(
                                invoiceID: formData.invoiceID,
                                amount: String(formData.amount),
                                paymentDate: String(formData.paymentDate),
                                paymentMethod: String(formData.paymentMethod),
                                comment: String(formData.comment)
                            )

                            Task { @MainActor in
                                let saved = await viewModel.createPayment(
                                    api: appState.api,
                                    formData: safeFormData
                                )

                                if saved {
                                    isShowingCreatePayment = false
                                }
                            }
                        }
                    )
                }
            }
            .sheet(item: $editingPayment) { payment in
                if let invoice = viewModel.invoices.first(where: { $0.id == payment.invoice_id }) {
                    PaymentFormView(
                        mode: .edit,
                        payment: payment,
                        invoice: invoice,
                        paymentMethods: viewModel.paymentMethods,
                        isSaving: viewModel.isSaving,
                        errorMessage: viewModel.errorMessage,
                        onSave: { formData in
                            let safeFormData = PaymentFormData(
                                invoiceID: formData.invoiceID,
                                amount: String(formData.amount),
                                paymentDate: String(formData.paymentDate),
                                paymentMethod: String(formData.paymentMethod),
                                comment: String(formData.comment)
                            )

                            Task { @MainActor in
                                let saved = await viewModel.updatePayment(
                                    api: appState.api,
                                    paymentID: payment.id,
                                    formData: safeFormData
                                )

                                if saved {
                                    editingPayment = nil
                                }
                            }
                        }
                    )
                }
            }
            .confirmationDialog(
                "Отменить счёт?",
                isPresented: $isShowingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Отменить счёт", role: .destructive) {
                    guard let invoiceToCancel else {
                        return
                    }

                    Task {
                        _ = await viewModel.cancelInvoice(
                            api: appState.api,
                            invoice: invoiceToCancel
                        )

                        self.invoiceToCancel = nil
                    }
                }

                Button("Назад", role: .cancel) {
                    invoiceToCancel = nil
                }
            } message: {
                if let invoiceToCancel {
                    Text("Счёт «\(invoiceToCancel.title)» будет отменён.")
                }
            }
            .confirmationDialog(
                "Удалить платёж?",
                isPresented: $isShowingDeletePaymentConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить платёж", role: .destructive) {
                    guard let paymentToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deletePayment(
                            api: appState.api,
                            payment: paymentToDelete
                        )

                        self.paymentToDelete = nil
                    }
                }

                Button("Назад", role: .cancel) {
                    paymentToDelete = nil
                }
            } message: {
                if let paymentToDelete {
                    Text("Платёж на сумму \(paymentToDelete.amount) будет удалён.")
                }
            }
            .alert(
                "Счета на следующий месяц",
                isPresented: $isShowingGenerateConfirmation
            ) {
                TextField("Сумма, ₽", text: $nextMonthAmount)
                    .keyboardType(.decimalPad)

                Button("Создать счета") {
                    let amount = nextMonthAmount

                    Task {
                        let created = await viewModel.generateNextMonthInvoices(
                            api: appState.api,
                            amountText: amount
                        )

                        if created {
                            nextMonthAmount = ""
                        }
                    }
                }
                .disabled(!isNextMonthAmountValid)

                Button("Отмена", role: .cancel) {}
            } message: {
                Text(nextMonthMessage)
            }
        }
    }

    private var isNextMonthAmountValid: Bool {
        guard let amount = FinanceMoney.decimal(from: nextMonthAmount) else {
            return false
        }

        return amount > 0
    }

    private var nextMonthMessage: String {
        let period = viewModel.nextMonthLabel.map { " за \($0)" } ?? ""
        return "Счёт на эту сумму получит каждый активный ученик\(period). Уже выставленные счета за этот месяц не перезаписываются."
    }

    private var financeList: some View {
        List {
            filtersSection

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }

            overviewSection
            invoicesSection
            paymentsSection
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
    }

    private var unavailableView: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.muted)

            Text("Финансы недоступны")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.heading)

            Text("Раздел финансов не доступен для ученика.")
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            if viewModel.isLoadingFilters {
                HStack {
                    Spacer()
                    ProgressView("Загрузка фильтров...")
                    Spacer()
                }
            }

            if !viewModel.students.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    Text("Все ученики").tag(0)

                    ForEach(viewModel.students) { student in
                        Text(student.student_name).tag(student.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }
            }

            Picker("Период", selection: $viewModel.selectedPeriod) {
                Text("Все периоды").tag("all")

                ForEach(viewModel.periods) { period in
                    Text(period.title).tag(period.code)
                }
            }
            .onChange(of: viewModel.selectedPeriod) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            Picker("Статус", selection: $viewModel.selectedStatus) {
                ForEach(viewModel.statuses, id: \.code) { status in
                    Text(status.title).tag(status.code)
                }
            }
            .onChange(of: viewModel.selectedStatus) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            Button {
                viewModel.selectedStudentID = 0
                viewModel.selectedPeriod = "all"
                viewModel.selectedStatus = "unpaid"
                viewModel.searchText = ""

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            } label: {
                Label("Показать неоплаченные", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var overviewSection: some View {
        Section {
            HStack(spacing: 12) {
                FinanceStatCard(
                    title: "К оплате",
                    value: viewModel.debtAmountText,
                    color: AppTheme.danger,
                    systemImage: "exclamationmark.triangle.fill"
                )

                FinanceStatCard(
                    title: "Не оплачено",
                    value: "\(viewModel.unpaidCount)",
                    color: AppTheme.warning,
                    systemImage: "doc.text.fill"
                )

                FinanceStatCard(
                    title: "Просрочено",
                    value: "\(viewModel.overdueCount)",
                    color: AppTheme.danger,
                    systemImage: "clock.badge.exclamationmark.fill"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if let overview = viewModel.overview {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Всего начислено")
                            .foregroundStyle(AppTheme.muted)

                        Spacer()

                        Text(overview.total_amount ?? viewModel.totalAmountText)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.text)
                    }

                    HStack {
                        Text("Оплачено")
                            .foregroundStyle(AppTheme.muted)

                        Spacer()

                        Text(overview.paid_amount ?? viewModel.paidAmountText)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.success)
                    }

                    HStack {
                        Text("Остаток")
                            .foregroundStyle(AppTheme.muted)

                        Spacer()

                        Text(overview.debt_amount ?? viewModel.debtAmountText)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
        } header: {
            Text("Сводка")
        }
    }

    private var invoicesSection: some View {
        Section("Счета") {
            if viewModel.isLoading && viewModel.invoices.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Загрузка счетов...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.warning)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)

                    Button("Повторить") {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.vertical)
            } else if viewModel.filteredInvoices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(AppTheme.muted)

                    Text("Счетов нет")
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Text(emptyInvoicesText)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)

                    if appState.canManageFinance {
                        Button {
                            isShowingCreateInvoice = true
                        } label: {
                            Label("Создать счёт", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredInvoices) { invoice in
                    Button {
                        selectedInvoice = invoice
                        viewModel.selectedInvoiceID = invoice.id

                        Task {
                            await viewModel.loadPayments(
                                api: appState.api,
                                invoiceID: invoice.id,
                                showLoading: false
                            )
                        }
                    } label: {
                        InvoiceRowView(
                            invoice: invoice,
                            statusTitle: viewModel.statusTitle(invoice.status),
                            isSelected: viewModel.selectedInvoiceID == invoice.id
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if appState.canManageFinance {
                            Button(role: .destructive) {
                                invoiceToCancel = invoice
                                isShowingCancelConfirmation = true
                            } label: {
                                Label("Отменить", systemImage: "xmark.circle")
                            }

                            Button {
                                editingInvoice = invoice
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button {
                                viewModel.selectedInvoiceID = invoice.id
                                isShowingCreatePayment = true
                            } label: {
                                Label("Платёж", systemImage: "creditcard.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
    }

    private var paymentsSection: some View {
        Section("Платежи") {
            if let invoice = viewModel.selectedInvoice {
                VStack(alignment: .leading, spacing: 8) {
                    Text(invoice.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Text(invoice.student_name)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                if viewModel.isLoadingPayments {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка платежей...")
                        Spacer()
                    }
                } else if viewModel.payments.isEmpty {
                    Text("Платежей по выбранному счёту пока нет.")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(viewModel.payments) { payment in
                        PaymentRowView(
                            payment: payment,
                            paymentMethodTitle: viewModel.paymentMethodTitle(payment.payment_method)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if appState.canManageFinance {
                                Button(role: .destructive) {
                                    paymentToDelete = payment
                                    isShowingDeletePaymentConfirmation = true
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }

                                Button {
                                    editingPayment = payment
                                } label: {
                                    Label("Изменить", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }

                if appState.canManageFinance {
                    Button {
                        isShowingCreatePayment = true
                    } label: {
                        Label("Добавить платёж", systemImage: "plus.circle.fill")
                    }
                }
            } else {
                Text("Выберите счёт, чтобы увидеть платежи.")
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var emptyInvoicesText: String {
        if viewModel.selectedStatus == "unpaid" {
            return "Неоплаченных счетов нет."
        }

        return "По выбранным фильтрам ничего не найдено."
    }
}

struct InvoiceRowView: View {
    let invoice: InvoiceDTO
    let statusTitle: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)

                    Text(invoice.student_name)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if let className = invoice.class_name, !className.isEmpty {
                        Text(className)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(invoice.amount)
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Text("Остаток: \(invoice.remainingAmount)")
                        .font(.caption)
                        .foregroundStyle(invoice.isPaid ? AppTheme.success : AppTheme.danger)
                }
            }

            HStack(spacing: 10) {
                Text(statusTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                if let dueDate = invoice.due_date {
                    Label(AppDateFormatter.date(dueDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                if let paidAmount = invoice.paid_amount, !paidAmount.isEmpty {
                    Label("Оплачено: \(paidAmount)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isSelected ? 8 : 0)
        .background {
            if isSelected {
                AppTheme.primarySoft.opacity(0.45)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        if invoice.isPaid {
            return AppTheme.success
        }

        if invoice.isOverdue {
            return AppTheme.danger
        }

        if invoice.isCancelled {
            return AppTheme.muted
        }

        return AppTheme.warning
    }
}

struct PaymentRowView: View {
    let payment: PaymentDTO
    let paymentMethodTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payment.amount)
                    .font(.headline)
                    .foregroundStyle(AppTheme.success)

                Spacer()

                Text(paymentMethodTitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            HStack {
                if let paymentDate = payment.payment_date {
                    Label(AppDateFormatter.date(paymentDate), systemImage: "calendar")
                }

                if let comment = payment.comment, !comment.isEmpty {
                    Label(comment, systemImage: "text.bubble")
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.muted)

            if let createdByName = payment.created_by_name, !createdByName.isEmpty {
                Label(createdByName, systemImage: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.vertical, 5)
    }
}

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let invoice: InvoiceDTO
    let statusTitle: String
    let invoiceItems: [InvoiceItemDTO]
    let canManage: Bool
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onPayments: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(statusTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())

                        Text(invoice.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.heading)

                        Label(invoice.student_name, systemImage: "person.fill")
                            .foregroundStyle(AppTheme.muted)

                        if let className = invoice.class_name {
                            Label(className, systemImage: "person.3.fill")
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Суммы") {
                    LabeledContent("Начислено", value: invoice.amount)

                    if let paidAmount = invoice.paid_amount {
                        LabeledContent("Оплачено", value: paidAmount)
                    }

                    LabeledContent("Остаток", value: invoice.remainingAmount)

                    if let paidPercent = invoice.paid_percent {
                        LabeledContent("Оплачено, %", value: paidPercent)
                    }
                }

                Section("Из чего сложилась сумма") {
                    if invoiceItems.isEmpty {
                        Text("Детализация по этому счёту пока не передана сервером.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)

                        if let description = invoice.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.text)
                        }
                    } else {
                        ForEach(invoiceItems) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.heading)

                                        Text(item.readableType)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.muted)
                                    }

                                    Spacer()

                                    Text(item.amount)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.text)
                                }

                                if let description = item.description, !description.isEmpty {
                                    Text(description)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.muted)
                                }

                                HStack {
                                    if let quantity = item.quantity {
                                        Label("Кол-во: \(quantity)", systemImage: "number")
                                    }

                                    if let unitPrice = item.unit_price {
                                        Label("Цена: \(unitPrice)", systemImage: "rublesign.circle")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)

                                HStack {
                                    if let dateFrom = item.date_from {
                                        Label(AppDateFormatter.date(dateFrom), systemImage: "calendar")
                                    }

                                    if let dateTo = item.date_to {
                                        Text("— \(AppDateFormatter.date(dateTo))")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section("Детали") {
                    if let description = invoice.description, !description.isEmpty {
                        Text(description)
                    }

                    if let dueDate = invoice.due_date {
                        LabeledContent("Срок оплаты", value: AppDateFormatter.date(dueDate))
                    }

                    if let period = invoice.period {
                        LabeledContent("Период", value: AppDateFormatter.monthYear(period))
                    }

                    if let start = invoice.period_starts_at {
                        LabeledContent("Начало периода", value: AppDateFormatter.date(start))
                    }

                    if let end = invoice.period_ends_at {
                        LabeledContent("Конец периода", value: AppDateFormatter.date(end))
                    }

                    if let invoiceType = invoice.invoice_type {
                        LabeledContent("Тип", value: invoiceType)
                    }
                }

                if canManage {
                    Section("Управление") {
                        Button {
                            onPayments()
                        } label: {
                            Label("Показать платежи", systemImage: "creditcard.fill")
                        }

                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onCancel()
                        } label: {
                            Label("Отменить счёт", systemImage: "xmark.circle")
                        }
                    }
                }

                Section("Система") {
                    LabeledContent("ID счёта", value: "\(invoice.id)")
                    LabeledContent("ID ученика", value: "\(invoice.student_id)")
                    LabeledContent("Статус", value: invoice.status)

                    if let createdAt = invoice.created_at {
                        LabeledContent("Создан", value: AppDateFormatter.dateTime(createdAt))
                    }

                    if let updatedAt = invoice.updated_at {
                        LabeledContent("Обновлён", value: AppDateFormatter.dateTime(updatedAt))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Счёт")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        if invoice.isPaid {
            return AppTheme.success
        }

        if invoice.isOverdue {
            return AppTheme.danger
        }

        if invoice.isCancelled {
            return AppTheme.muted
        }

        return AppTheme.warning
    }
}

struct FinanceStatCard: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.sidebar.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}