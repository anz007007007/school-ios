import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            List {
                headerSection
                sectionPicker

                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Загрузка аналитики...")
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.warning)

                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)

                            Button("Повторить") {
                                Task {
                                    await viewModel.loadAll(api: appState.api)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical)
                    }
                }

                selectedContent
            }
            .appThemedList()
            .navigationTitle("Аналитика")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Поиск")
            .refreshable {
                await viewModel.loadAll(api: appState.api)
            }
            .task {
                await viewModel.loadAll(api: appState.api)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadAll(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.primarySoft)
                            .frame(width: 54, height: 54)

                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundStyle(AppTheme.sidebar)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Аналитика школы")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Text("Полная сводка по ученикам, сотрудникам, финансам, активности и коммуникациям.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var sectionPicker: some View {
        Section {
            Picker("Раздел", selection: $viewModel.selectedSection) {
                ForEach(AnalyticsViewModel.AnalyticsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedSection) { _ in
                Task {
                    await viewModel.loadSection(api: appState.api)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch viewModel.selectedSection {
        case .overview:
            metricsSection("Ключевые показатели", metrics: viewModel.overviewMetrics)
            chartSection("Роли", items: viewModel.dashboard?.overview?.role_distribution ?? viewModel.overview?.role_distribution ?? [])
            chartSection("Классы", items: viewModel.dashboard?.overview?.class_distribution ?? viewModel.overview?.class_distribution ?? [])
            chartSection("Платформы приложения", items: viewModel.dashboard?.overview?.app_platform_distribution ?? viewModel.overview?.app_platform_distribution ?? [])
            chartSection("Активность входов", items: viewModel.dashboard?.overview?.login_activity ?? viewModel.overview?.login_activity ?? [])

        case .students:
            metricsSection("Ученики", metrics: viewModel.studentsMetrics)
            studentPerformanceSection
            chartSection("Успеваемость", items: viewModel.dashboard?.students?.performance_distribution ?? viewModel.students?.performance_distribution ?? [])
            chartSection("Риски", items: viewModel.dashboard?.students?.risk_distribution ?? viewModel.students?.risk_distribution ?? [])
            chartSection("Распределение по классам", items: viewModel.dashboard?.students?.class_distribution ?? viewModel.students?.class_distribution ?? [])
            chartSection("Посещаемость", items: viewModel.dashboard?.students?.attendance_distribution ?? viewModel.students?.attendance_distribution ?? [])

        case .teachers:
            metricsSection("Сводка", metrics: viewModel.teachersSummary)
            teachersSection

        case .parents:
            metricsSection("Родители", metrics: viewModel.parentsMetrics)
            chartSection("Связанные дети", items: viewModel.dashboard?.parents?.linked_children_distribution ?? viewModel.parents?.linked_children_distribution ?? [])
            chartSection("Вовлечённость", items: viewModel.dashboard?.parents?.engagement_distribution ?? viewModel.parents?.engagement_distribution ?? [])
            chartSection("Активность", items: viewModel.dashboard?.parents?.activity ?? viewModel.parents?.activity ?? [])

        case .engagement:
            metricsSection("Активность", metrics: viewModel.engagementMetrics)
            chartSection("Активные пользователи по ролям", items: viewModel.dashboard?.engagement?.active_users_by_role ?? viewModel.engagement?.active_users_by_role ?? [])
            chartSection("Неактивные пользователи по ролям", items: viewModel.dashboard?.engagement?.inactive_users_by_role ?? viewModel.engagement?.inactive_users_by_role ?? [])
            chartSection("Платформы", items: viewModel.dashboard?.engagement?.platform_distribution ?? viewModel.engagement?.platform_distribution ?? [])
            chartSection("Активные пользователи по дням", items: viewModel.dashboard?.engagement?.daily_active_users ?? viewModel.engagement?.daily_active_users ?? [])
            chartSection("Использование функций", items: viewModel.dashboard?.engagement?.feature_usage ?? viewModel.engagement?.feature_usage ?? [])
            chartSection("Активность по ролям", items: viewModel.dashboard?.engagement?.role_activity ?? viewModel.engagement?.role_activity ?? [])

        case .finance:
            metricsSection("Финансы", metrics: viewModel.financeMetrics)
            chartSection("Статусы счетов", items: viewModel.dashboard?.finance?.invoice_status_distribution ?? viewModel.finance?.invoice_status_distribution ?? [])
            chartSection("Способы оплаты", items: viewModel.dashboard?.finance?.payment_method_distribution ?? viewModel.finance?.payment_method_distribution ?? [])
            chartSection("Платежи по месяцам", items: viewModel.dashboard?.finance?.monthly_payments ?? viewModel.finance?.monthly_payments ?? [])
            debtorsSection

        case .health:
            metricsSection("Здоровье", metrics: viewModel.healthMetrics)
            chartSection("Риски", items: viewModel.dashboard?.health?.risk_distribution ?? viewModel.health?.risk_distribution ?? [])
            chartSection("Медкарты по классам", items: viewModel.dashboard?.health?.health_cards_by_class ?? viewModel.health?.health_cards_by_class ?? [])
            chartSection("Группы здоровья", items: viewModel.dashboard?.health?.health_groups ?? viewModel.health?.health_groups ?? [])
            chartSection("Аллергии", items: viewModel.dashboard?.health?.allergy_distribution ?? viewModel.health?.allergy_distribution ?? [])
            chartSection("Медицинские отметки", items: viewModel.dashboard?.health?.medical_notes ?? viewModel.health?.medical_notes ?? [])

        case .communications:
            metricsSection("Коммуникации", metrics: viewModel.communicationMetrics)
            chartSection("Сообщения по ролям", items: viewModel.dashboard?.communications?.message_activity_by_role ?? viewModel.communications?.message_activity_by_role ?? [])
            chartSection("Непрочитанные по ролям", items: viewModel.dashboard?.communications?.unread_by_role ?? viewModel.communications?.unread_by_role ?? [])
            chartSection("Уведомления по типам", items: viewModel.dashboard?.communications?.notifications_by_type ?? viewModel.communications?.notifications_by_type ?? [])
            chartSection("Сообщения по дням", items: viewModel.dashboard?.communications?.messages_by_day ?? viewModel.communications?.messages_by_day ?? [])
            chartSection("Объявления по дням", items: viewModel.dashboard?.communications?.announcements_by_day ?? viewModel.communications?.announcements_by_day ?? [])
            chartSection("По ролям", items: viewModel.dashboard?.communications?.role_distribution ?? viewModel.communications?.role_distribution ?? [])
        }
    }

    private func metricsSection(
        _ title: String,
        metrics: [AnalyticsMetricDTO]
    ) -> some View {
        Section(title) {
            if metrics.isEmpty {
                emptyText("Показателей пока нет.")
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(metrics) { metric in
                        AnalyticsMetricCardView(metric: metric)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private func chartSection(
        _ title: String,
        items: [AnalyticsChartPointDTO]
    ) -> some View {
        Section(title) {
            if items.isEmpty {
                emptyText("Данных пока нет.")
            } else {
                ForEach(items) { item in
                    AnalyticsChartRowView(item: item, maxValue: maxChartValue(items))
                }
            }
        }
    }

    private var studentPerformanceSection: some View {
        Section("Успеваемость учеников") {
            if viewModel.filteredStudentPerformance.isEmpty {
                emptyText("Ученики не найдены.")
            } else {
                ForEach(viewModel.filteredStudentPerformance) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.displayName)
                                    .font(.headline)

                                Text(item.class_name ?? "Класс не указан")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }

                            Spacer()

                            if let average = item.average_grade {
                                Text(String(format: "%.2f", average))
                                    .font(.headline)
                                    .foregroundStyle(colorForAverage(average))
                            } else if let riskLevel = item.risk_level, !riskLevel.isEmpty {
                                Text(riskLevel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.warning.opacity(0.15))
                                    .foregroundStyle(AppTheme.warning)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack {
                            Label("\(item.grades_count ?? 0) оценок", systemImage: "book.closed.fill")
                            Label("\(item.excellent_count ?? 0) отлично", systemImage: "5.circle.fill")
                            Label("\(item.good_count ?? 0) хорошо", systemImage: "4.circle.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)

                        HStack {
                            Label("\(item.bad_count ?? 0) рисковых", systemImage: "exclamationmark.triangle.fill")
                            Label("\(item.absence_count ?? item.missed_lessons ?? 0) пропусков", systemImage: "xmark.circle.fill")
                            Label("\(item.late_count ?? 0) опозданий", systemImage: "clock.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)

                        if let attendance = item.attendance_percent {
                            Label(String(format: "Посещаемость %.1f%%", attendance), systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var teachersSection: some View {
        Section("Учителя") {
            if viewModel.filteredTeachers.isEmpty {
                emptyText("Учителя не найдены.")
            } else {
                ForEach(viewModel.filteredTeachers) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.displayName)
                                .font(.headline)

                            Spacer()

                            if let average = item.average_grade {
                                Text(String(format: "%.2f", average))
                                    .font(.headline)
                                    .foregroundStyle(colorForAverage(average))
                            }
                        }

                        HStack {
                            Label("\(item.subjects_count ?? 0) предметов", systemImage: "books.vertical.fill")
                            Label("\(item.classes_count ?? 0) классов", systemImage: "person.3.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)

                        HStack {
                            Label("\(item.grades_count ?? 0) оценок", systemImage: "checkmark.circle.fill")
                            Label("\(item.homework_count ?? 0) ДЗ", systemImage: "pencil.and.list.clipboard")
                            Label("\(item.attendance_count ?? 0) посещ.", systemImage: "calendar.badge.checkmark")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var debtorsSection: some View {
        Section("Должники") {
            if viewModel.filteredDebtors.isEmpty {
                emptyText("Должников нет.")
            } else {
                ForEach(viewModel.filteredDebtors) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.headline)

                            Text(item.class_name ?? "Класс не указан")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(item.displayDebt)
                                .font(.headline)
                                .foregroundStyle(AppTheme.danger)

                            Text("\(item.invoices_count ?? 0) счетов")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func maxChartValue(_ items: [AnalyticsChartPointDTO]) -> Double {
        max(items.map(\.numericValue).max() ?? 1, 1)
    }

    private func colorForAverage(_ value: Double?) -> Color {
        guard let value else {
            return AppTheme.muted
        }

        if value >= 4.5 {
            return AppTheme.success
        }

        if value >= 3.5 {
            return .blue
        }

        if value >= 2.5 {
            return AppTheme.warning
        }

        return AppTheme.danger
    }
}

struct AnalyticsMetricCardView: View {
    let metric: AnalyticsMetricDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(AppTheme.sidebar)

            Text(metric.displayValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metric.displayTitle)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)

            if let subtitle = metric.displaySubtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var iconName: String {
        let lower = metric.displayTitle.lowercased()

        if lower.contains("учен") {
            return "graduationcap.fill"
        }

        if lower.contains("учител") {
            return "person.text.rectangle.fill"
        }

        if lower.contains("родител") {
            return "figure.2.and.child.holdinghands"
        }

        if lower.contains("финанс") || lower.contains("долг") || lower.contains("плат") {
            return "creditcard.fill"
        }

        if lower.contains("сообщ") || lower.contains("объяв") {
            return "bubble.left.and.bubble.right.fill"
        }

        if lower.contains("здоров") || lower.contains("мед") {
            return "heart.text.square.fill"
        }

        return "chart.bar.fill"
    }
}

struct AnalyticsChartRowView: View {
    let item: AnalyticsChartPointDTO
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.displayLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Text(item.displayValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.sidebar)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.primarySoft)

                    Capsule()
                        .fill(AppTheme.sidebar)
                        .frame(width: barWidth(totalWidth: geometry.size.width))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 6)
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        guard maxValue > 0 else {
            return 0
        }

        let ratio = min(max(item.numericValue / maxValue, 0), 1)
        return totalWidth * ratio
    }
}