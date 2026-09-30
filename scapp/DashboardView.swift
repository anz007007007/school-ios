import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    @State private var didLoadInitialDashboard = false
    @State private var lastDashboardRefreshDate = Date.distantPast
    @State private var isUserRefreshing = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerView

                    VStack(alignment: .leading, spacing: 18) {
                        if viewModel.isLoading && !viewModel.hasLoadedInitialData {
                            ProgressView("Загружаем главную...")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            errorView(errorMessage)
                        }

                        if appState.isParent {
                            studentSelectorSection
                            subjectAveragesSection
                        } else if appState.isStudent {
                            subjectAveragesSection
                        }

                        if !viewModel.summaryCards.isEmpty {
                            serverCardsSection
                        } else if let analytics = viewModel.analytics, appState.isAdmin || appState.isManager {
                            analyticsSection(analytics)
                        }

                        if shouldShowBirthdaysSection {
                            birthdaysSection
                        }

                        featuresSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                isUserRefreshing = true
                await reloadDashboard(force: true)
                await appState.refreshUnreadNotificationsBySection()
                isUserRefreshing = false
            }
            .task {
                guard !didLoadInitialDashboard else {
                    return
                }

                async let dashboardTask: Void = reloadDashboard(force: true)
                async let unreadTask: Void = appState.refreshUnreadNotificationsBySection()

                _ = await (dashboardTask, unreadTask)

                if viewModel.hasLoadedInitialData {
                    didLoadInitialDashboard = true
                }
            }
            .onAppear {
                guard !isUserRefreshing else {
                    return
                }

                Task {
                    if !viewModel.hasLoadedInitialData {
                        await reloadDashboard(force: true)
                        await appState.refreshUnreadNotificationsBySection()

                        if viewModel.hasLoadedInitialData {
                            didLoadInitialDashboard = true
                        }

                        return
                    }

                    if shouldRefreshOnAppear {
                        await reloadDashboard(force: false)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await reloadDashboard(force: true)
                            await appState.refreshUnreadNotificationsBySection()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading || isUserRefreshing)
                }
            }
        }
    }

    private var shouldRefreshOnAppear: Bool {
        Date().timeIntervalSince(lastDashboardRefreshDate) > 60
    }

    private func reloadDashboard(force: Bool) async {
        guard force || shouldRefreshOnAppear else {
            return
        }

        guard !viewModel.isLoading else {
            return
        }

        lastDashboardRefreshDate = Date()

        await viewModel.loadInitialData(
            api: appState.api,
            isParent: appState.isParent,
            isStudent: appState.isStudent,
            isAdmin: appState.isAdmin || appState.isManager
        )
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(headerTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.heading.opacity(0.78))

                Spacer()

                NavigationLink {
                    ProfileView()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: appState.isParent ? "person.2.fill" : "person.badge.key.fill")
                            .font(.caption2)

                        Text(appState.userRoleName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(AppTheme.heading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.30))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text(headerSubtitle)
                .font(.title3)
                .fontWeight(.black)
                .foregroundStyle(AppTheme.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(AppTheme.navGradient)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.55))
                .frame(height: 1)
        }
    }

    private var headerTitle: String {
        "Здравствуйте,"
    }

    private var headerSubtitle: String {
        appState.userFullName
    }

    private var shouldShowBirthdaysSection: Bool {
        (appState.isAdmin || appState.isManager || appState.isTeacher)
        && !viewModel.birthdays.isEmpty
    }

    private var studentSelectorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.parentStudents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.control)

                    Text("Ребёнок: связанные дети не найдены")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            } else {
                Menu {
                    ForEach(viewModel.parentStudents) { student in
                        Button {
                            guard viewModel.selectedStudentID != student.id else {
                                return
                            }

                            viewModel.selectedStudentID = student.id

                            Task {
                                await viewModel.selectStudent(
                                    api: appState.api,
                                    studentID: student.id
                                )
                            }
                        } label: {
                            Text(student.displayName)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.control)

                        Text("Ребёнок:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.muted)

                        Text(viewModel.selectedStudent?.displayName ?? "Выберите ребёнка")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)

                        if let student = viewModel.selectedStudent {
                            Text(student.displaySubtitle)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.sidebar.opacity(0.04), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var subjectAveragesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Средние оценки")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)

                    Text(viewModel.totalAverageText)
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundStyle(colorForAverageText(viewModel.totalAverageText))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }

                Text("Текущая четверть: \(viewModel.currentQuarterTitle)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if viewModel.isLoadingStudentGrades {
                ProgressView("Загружаем оценки...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            } else if viewModel.subjectAverages.isEmpty {
                Text("Оценок за текущую четверть пока нет.")
                    .foregroundStyle(AppTheme.muted)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text("Предмет")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Кол.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 34, alignment: .center)

                        Text("Сегодня")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 58, alignment: .center)

                        Text("Ср.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 42, alignment: .trailing)

                        Text("Чтв.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 38, alignment: .center)

                        Text("Год")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 34, alignment: .center)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.primarySoft.opacity(0.65))

                    ForEach(viewModel.subjectAverages) { item in
                        HStack(spacing: 4) {
                            Text(item.subjectName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)

                            Text("\(item.gradesCount)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                                .frame(width: 34, alignment: .center)

                            Text(item.todayGradesText)
                                .font(.caption2)
                                .fontWeight(item.todayGradesText == "—" ? .regular : .bold)
                                .foregroundColor(item.todayGradesText == "—" ? AppTheme.muted : Color.blue)
                                .frame(width: 58, alignment: .center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(item.averageText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(colorForAverage(item.average))
                                .frame(width: 42, alignment: .trailing)
                                .minimumScaleFactor(0.8)

                            calculatedGradeBadge(item.calculatedQuarterGradeText)
                                .frame(width: 38, alignment: .center)

                            calculatedGradeBadge(item.calculatedYearGradeText)
                                .frame(width: 34, alignment: .center)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)

                        if item.id != viewModel.subjectAverages.last?.id {
                            Divider()
                                .padding(.leading, 10)
                        }
                    }
                }
                .background(AppTheme.card.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private func calculatedGradeBadge(_ value: String) -> some View {
        Text(value)
            .font(.caption2)
            .fontWeight(.bold)
            .frame(minWidth: 24, minHeight: 22)
            .background(colorForCalculatedGrade(value).opacity(0.14))
            .foregroundStyle(colorForCalculatedGrade(value))
            .clipShape(Capsule())
    }

    private func colorForCalculatedGrade(_ value: String) -> Color {
        switch value {
        case "5":
            return AppTheme.success
        case "4":
            return .blue
        case "3":
            return AppTheme.warning
        case "2":
            return AppTheme.danger
        default:
            return AppTheme.muted
        }
    }

    private var serverCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сводка")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.summaryCards.filter { !isDocumentsCard($0.title) }) { card in
                    NavigationLink {
                        summaryDestination(for: card)
                    } label: {
                        DashboardServerCardView(
                            title: card.title,
                            value: card.value,
                            color: colorForCard(card.title),
                            systemImage: iconForCard(card.title),
                            unreadCount: unreadCount(for: summaryTarget(for: card.title))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func summaryDestination(for card: DashboardSummaryCard) -> some View {
        switch summaryTarget(for: card.title) {
        case .diary:
            DiaryView()
        case .homework:
            HomeworkView()
        case .messages:
            MessagesView()
        case .events:
            EventsView()
        case .clubs:
            ClubsView()
        case .finance:
            if appState.canUseFinance {
                FinanceView()
            } else {
                DashboardSummaryUnsupportedView(
                    title: "Финансы",
                    value: "Раздел недоступен для ученика"
                )
            }
        case .health:
            HealthView()
        case .schedule:
            ScheduleView()
        case .documents:
            DashboardSummaryUnsupportedView(
                title: "Документы",
                value: "Раздел документов скрыт с главной страницы"
            )
        case .menu:
            SchoolMenuView()
        case .textbooks:
            TextbooksView()
        case .portfolio:
            PortfolioView()
        case .teacher:
            TeacherCabinetView()
        case .analytics:
            AnalyticsView()
        case .admin:
            AdminView()
        case .unsupported:
            DashboardSummaryUnsupportedView(title: card.title, value: card.value)
        }
    }

    private func analyticsSection(_ analytics: AnalyticsResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Аналитика")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink {
                    AdminView()
                } label: {
                    DashboardServerCardView(
                        title: "Ученики",
                        value: "\(analytics.students ?? 0)",
                        color: .blue,
                        systemImage: "graduationcap.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AdminView()
                } label: {
                    DashboardServerCardView(
                        title: "Активные",
                        value: "\(analytics.active_students ?? 0)",
                        color: .green,
                        systemImage: "checkmark.circle.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AdminView()
                } label: {
                    DashboardServerCardView(
                        title: "Учителя",
                        value: "\(analytics.teachers ?? 0)",
                        color: .purple,
                        systemImage: "person.text.rectangle.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AdminView()
                } label: {
                    DashboardServerCardView(
                        title: "Классы",
                        value: "\(analytics.classes ?? 0)",
                        color: .orange,
                        systemImage: "person.3.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FinanceView()
                } label: {
                    DashboardServerCardView(
                        title: "Долг",
                        value: analytics.finance_total_debt ?? "0",
                        color: .red,
                        systemImage: "creditcard.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FinanceView()
                } label: {
                    DashboardServerCardView(
                        title: "Просрочено",
                        value: "\(analytics.overdue_invoices ?? 0)",
                        color: .red,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var birthdaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pink.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: "birthday.cake.fill")
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Дни рождения")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Text("За 2 дня назад, сегодня и на 5 дней вперёд")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Text("\(viewModel.birthdays.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.pink.opacity(0.12))
                    .foregroundStyle(.pink)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.todayBirthdays.isEmpty {
                    DashboardBirthdayGroupView(
                        title: "Сегодня",
                        systemImage: "gift.fill",
                        color: .pink,
                        items: viewModel.todayBirthdays
                    )
                }

                if !viewModel.upcomingBirthdays.isEmpty {
                    DashboardBirthdayGroupView(
                        title: "Скоро",
                        systemImage: "calendar.badge.clock",
                        color: .blue,
                        items: viewModel.upcomingBirthdays
                    )
                }

                if !viewModel.pastBirthdays.isEmpty {
                    DashboardBirthdayGroupView(
                        title: "Недавно были",
                        systemImage: "clock.arrow.circlepath",
                        color: .orange,
                        items: viewModel.pastBirthdays
                    )
                }
            }
            .padding()
            .background(AppTheme.card.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.sidebar.opacity(0.06), radius: 14, x: 0, y: 7)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Разделы")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            LazyVGrid(columns: columns, spacing: 16) {
                if appState.isCook {
                    NavigationLink {
                        SchoolMenuView()
                    } label: {
                        FeatureCardView(
                            title: "Меню",
                            subtitle: "Блюда и меню на неделю",
                            systemImage: "fork.knife.circle.fill",
                            color: .mint,
                            unreadCount: appState.unreadNotificationsCount(for: "menu")
                        )
                    }

                    NavigationLink {
                        HealthView()
                    } label: {
                        FeatureCardView(
                            title: "Здоровье",
                            subtitle: "Просмотр медкарт",
                            systemImage: "heart.text.square.fill",
                            color: .red,
                            unreadCount: appState.unreadNotificationsCount(for: "health")
                        )
                    }
                } else {
                    if viewModel.featureEnabled("diary") {
                        NavigationLink {
                            DiaryView()
                        } label: {
                            FeatureCardView(
                                title: "Дневник",
                                subtitle: "Оценки и средний балл",
                                systemImage: "book.closed.fill",
                                color: .blue,
                                unreadCount: appState.unreadNotificationsCount(for: "diary")
                            )
                        }
                    }

                    if viewModel.featureEnabled("homework") {
                        NavigationLink {
                            HomeworkView()
                        } label: {
                            FeatureCardView(
                                title: "Домашка",
                                subtitle: "Задания и сроки",
                                systemImage: "pencil.and.list.clipboard",
                                color: .orange,
                                unreadCount: appState.unreadNotificationsCount(for: "homework")
                            )
                        }
                    }

                    NavigationLink {
                        ScheduleView()
                    } label: {
                        FeatureCardView(
                            title: "Расписание",
                            subtitle: "Уроки по дням",
                            systemImage: "calendar",
                            color: .green,
                            unreadCount: appState.unreadNotificationsCount(for: "schedule")
                        )
                    }

                    if appState.isAdmin || appState.isManager || appState.isTeacher || appState.isParent || appState.isStudent {
                        NavigationLink {
                            PortfolioView()
                        } label: {
                            FeatureCardView(
                                title: "Портфолио",
                                subtitle: "Достижения, проекты и рейтинг",
                                systemImage: "person.crop.square.fill",
                                color: .indigo,
                                unreadCount: appState.unreadNotificationsCount(for: "portfolio")
                            )
                        }
                    }

                    if appState.isAdmin || appState.isManager || appState.isTeacher || appState.isParent {
                        NavigationLink {
                            CommunityView()
                        } label: {
                            FeatureCardView(
                                title: "Объявления",
                                subtitle: "Предложения родителей и потребности школы",
                                systemImage: "megaphone.fill",
                                color: .teal,
                                unreadCount: appState.unreadNotificationsCount(for: "community")
                            )
                        }
                    }

                    if appState.canViewTextbooks {
                        NavigationLink {
                            TextbooksView()
                        } label: {
                            FeatureCardView(
                                title: "Учебники",
                                subtitle: appState.canManageTextbooks ? "Материалы и управление" : "Просмотр и скачивание",
                                systemImage: "books.vertical.fill",
                                color: .blue,
                                unreadCount: appState.unreadNotificationsCount(for: "textbooks")
                            )
                        }
                    }

                    if viewModel.featureEnabled("messages") {
                        NavigationLink {
                            MessagesView()
                        } label: {
                            FeatureCardView(
                                title: "Сообщения",
                                subtitle: "Письма и объявления",
                                systemImage: "envelope.fill",
                                color: .cyan,
                                unreadCount: appState.unreadNotificationsCount(for: "messages")
                            )
                        }
                    }

                    if viewModel.featureEnabled("events") {
                        NavigationLink {
                            EventsView()
                        } label: {
                            FeatureCardView(
                                title: "События",
                                subtitle: "Мероприятия и таймлайн",
                                systemImage: "party.popper.fill",
                                color: .purple,
                                unreadCount: appState.unreadNotificationsCount(for: "events")
                            )
                        }
                    }

                    if viewModel.featureEnabled("clubs") {
                        NavigationLink {
                            ClubsView()
                        } label: {
                            FeatureCardView(
                                title: "Кружки",
                                subtitle: "Секции и занятия",
                                systemImage: "star.circle.fill",
                                color: .pink,
                                unreadCount: appState.unreadNotificationsCount(for: "clubs")
                            )
                        }
                    }

                    NavigationLink {
                        SchoolMenuView()
                    } label: {
                        FeatureCardView(
                            title: "Меню",
                            subtitle: "Питание на неделю",
                            systemImage: "fork.knife.circle.fill",
                            color: .mint,
                            unreadCount: appState.unreadNotificationsCount(for: "menu")
                        )
                    }

                    if appState.canViewHealth {
                        NavigationLink {
                            HealthView()
                        } label: {
                            FeatureCardView(
                                title: "Здоровье",
                                subtitle: "Медкарта и отметки",
                                systemImage: "heart.text.square.fill",
                                color: .red,
                                unreadCount: appState.unreadNotificationsCount(for: "health")
                            )
                        }
                    }

                    if viewModel.featureEnabled("finance") && appState.canUseFinance {
                        NavigationLink {
                            FinanceView()
                        } label: {
                            FeatureCardView(
                                title: "Финансы",
                                subtitle: "Счета и платежи",
                                systemImage: "creditcard.fill",
                                color: .green,
                                unreadCount: appState.unreadNotificationsCount(for: "finance")
                            )
                        }
                    }

                    if appState.isAdmin || appState.isManager {
                        NavigationLink {
                            AnalyticsView()
                        } label: {
                            FeatureCardView(
                                title: "Аналитика",
                                subtitle: "Сводка по школе и показателям",
                                systemImage: "chart.bar.xaxis",
                                color: .indigo
                            )
                        }
                    }

                    if appState.canOpenTeacherCabinet {
                        NavigationLink {
                            TeacherCabinetView()
                        } label: {
                            FeatureCardView(
                                title: "Учителю",
                                subtitle: "Журнал и уроки",
                                systemImage: "person.text.rectangle.fill",
                                color: .orange
                            )
                        }
                    }

                    if appState.isAdmin {
                        NavigationLink {
                            AdminView()
                        } label: {
                            FeatureCardView(
                                title: "Админка",
                                subtitle: "Управление системой",
                                systemImage: "gearshape.2.fill",
                                color: .red
                            )
                        }
                    }
                }
            }
        }
    }

    private func summaryTarget(for title: String) -> DashboardSummaryTarget {
        let lower = title.lowercased()

        if lower == "расписание" {
            return .schedule
        }

        if lower.contains("урок")
            || lower.contains("распис")
            || lower.contains("schedule")
            || lower.contains("lesson") {
            return .schedule
        }

        if lower.contains("предмет")
            || lower.contains("subject") {
            if appState.isTeacher || appState.canOpenTeacherCabinet {
                return .teacher
            }

            if appState.isAdmin || appState.isManager {
                return .admin
            }

            return .schedule
        }

        if lower.contains("оцен") || lower.contains("днев") || lower.contains("средн") {
            return .diary
        }

        if lower.contains("дом") || lower.contains("задан") {
            return .homework
        }

        if lower.contains("сообщ")
            || lower.contains("пись")
            || lower.contains("непрочит")
            || lower.contains("прочит")
            || lower.contains("входящ")
            || lower.contains("чат") {
            return .messages
        }

        if lower.contains("собы") || lower.contains("мероприят") {
            return .events
        }

        if lower.contains("круж") || lower.contains("секц") {
            return .clubs
        }

        if appState.canUseFinance
            && (
                lower.contains("финанс")
                || lower.contains("долг")
                || lower.contains("сч")
                || lower.contains("плат")
                || lower.contains("проср")
            ) {
            return .finance
        }

        if lower.contains("здоров") || lower.contains("мед") {
            return .health
        }

        if lower.contains("документ") || lower.contains("справ") {
            return .documents
        }

        if lower.contains("меню") || lower.contains("питан") {
            return .menu
        }

        if lower.contains("учебник") || lower.contains("материал") || lower.contains("пособ") {
            return .textbooks
        }

        if lower.contains("портфолио") || lower.contains("достижен") || lower.contains("проект") {
            return .portfolio
        }

        if lower.contains("учител") || lower.contains("журнал") {
            return .teacher
        }

        if lower.contains("аналит") {
            return .analytics
        }

        if lower.contains("класс") {
            if appState.isTeacher || appState.canOpenTeacherCabinet {
                return .teacher
            }

            return .admin
        }

        if lower.contains("админ") || lower.contains("ученик") {
            return .admin
        }

        return .unsupported
    }

    private func isDocumentsCard(_ title: String) -> Bool {
        let lower = title.lowercased()
        return lower.contains("документ") || lower.contains("справ")
    }

    private func colorForAverageText(_ value: String) -> Color {
        let normalized = value
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let number = Double(normalized) else {
            return AppTheme.muted
        }

        return colorForAverage(number)
    }

    private func colorForAverage(_ value: Double?) -> Color {
        guard let value else {
            return AppTheme.muted
        }

        if value >= 4.67 {
            return AppTheme.success
        }

        if value >= 3.67 {
            return .blue
        }

        if value >= 2.67 {
            return AppTheme.warning
        }

        return AppTheme.danger
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ошибка загрузки главной", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            Button {
                Task {
                    await reloadDashboard(force: true)
                }
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func iconForCard(_ title: String) -> String {
        let lower = title.lowercased()

        if lower == "расписание" {
            return "calendar"
        }

        if lower.contains("урок") || lower.contains("распис") {
            return "calendar"
        }

        if lower.contains("предмет") {
            return "book.fill"
        }

        if lower.contains("оцен") || lower.contains("средн") || lower.contains("днев") {
            return "book.closed.fill"
        }

        if lower.contains("сообщ")
            || lower.contains("пись")
            || lower.contains("непрочит")
            || lower.contains("прочит")
            || lower.contains("входящ")
            || lower.contains("чат") {
            return "envelope.fill"
        }

        if lower.contains("долг") || lower.contains("финанс") || lower.contains("сч") || lower.contains("плат") {
            return "creditcard.fill"
        }

        if lower.contains("дом") || lower.contains("задан") {
            return "pencil.and.list.clipboard"
        }

        if lower.contains("собы") {
            return "party.popper.fill"
        }

        if lower.contains("учен") {
            return "graduationcap.fill"
        }

        if lower.contains("меню") || lower.contains("питан") {
            return "fork.knife.circle.fill"
        }

        if lower.contains("учебник") || lower.contains("материал") || lower.contains("пособ") {
            return "books.vertical.fill"
        }

        if lower.contains("портфолио") || lower.contains("достижен") || lower.contains("проект") {
            return "person.crop.square.fill"
        }

        if lower.contains("учител") || lower.contains("журнал") {
            return "person.text.rectangle.fill"
        }

        return "chart.bar.fill"
    }

    private func colorForCard(_ title: String) -> Color {
        let lower = title.lowercased()

        if lower == "расписание" {
            return .green
        }

        if lower.contains("долг") || lower.contains("проср") {
            return AppTheme.danger
        }

        if lower.contains("оплач") || lower.contains("актив") {
            return AppTheme.success
        }

        if lower.contains("урок") || lower.contains("распис") {
            return .green
        }

        if lower.contains("предмет") {
            return .orange
        }

        if lower.contains("сообщ")
            || lower.contains("пись")
            || lower.contains("непрочит")
            || lower.contains("прочит")
            || lower.contains("входящ")
            || lower.contains("чат") {
            return .cyan
        }

        if lower.contains("собы") {
            return .purple
        }

        if lower.contains("дом") {
            return .orange
        }

        if lower.contains("оцен") || lower.contains("средн") {
            return .blue
        }

        if lower.contains("учебник") || lower.contains("материал") {
            return .blue
        }

        if lower.contains("портфолио") || lower.contains("достижен") || lower.contains("проект") {
            return .indigo
        }

        return AppTheme.sidebar
    }

    private func unreadCount(for target: DashboardSummaryTarget) -> Int {
        switch target {
        case .diary:
            return appState.unreadNotificationsCount(for: "diary")
        case .homework:
            if let dashboardHomeworkIncompleteCount = viewModel.dashboardHomeworkIncompleteCount {
                return dashboardHomeworkIncompleteCount
            }

            return appState.unreadNotificationsCount(for: "homework")
        case .messages:
            return appState.unreadNotificationsCount(for: "messages")
        case .events:
            return appState.unreadNotificationsCount(for: "events")
        case .clubs:
            return appState.unreadNotificationsCount(for: "clubs")
        case .finance:
            return appState.unreadNotificationsCount(for: "finance")
        case .health:
            return appState.unreadNotificationsCount(for: "health")
        case .schedule:
            return appState.unreadNotificationsCount(for: "schedule")
        case .documents:
            return appState.unreadNotificationsCount(for: "documents")
        case .menu:
            return appState.unreadNotificationsCount(for: "menu")
        case .textbooks:
            return appState.unreadNotificationsCount(for: "textbooks")
        case .portfolio:
            return appState.unreadNotificationsCount(for: "portfolio")
        case .teacher, .analytics, .admin, .unsupported:
            return 0
        }
    }
}

struct DashboardServerCardView: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String
    let unreadCount: Int

    init(
        title: String,
        value: String,
        color: Color,
        systemImage: String,
        unreadCount: Int = 0
    ) {
        self.title = title
        self.value = value
        self.color = color
        self.systemImage = systemImage
        self.unreadCount = unreadCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)

                UnreadBadgeView(count: unreadCount)
                    .offset(x: 8, y: -8)
            }

            Text(value)
                .font(.headline)
                .fontWeight(.black)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(10)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.sidebar.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct DashboardSummaryUnsupportedView: View {
    let title: String
    let value: String

    var body: some View {
        List {
            Section {
                Label("Раздел пока не определён", systemImage: "questionmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.warning)

                LabeledContent(title, value: value)

                Text("Плитка сводки открылась, но приложение пока не знает, в какой раздел её направить.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Сводка")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DashboardBirthdayGroupView: View {
    let title: String
    let systemImage: String
    let color: Color
    let items: [DashboardBirthdayDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    DashboardBirthdayRowView(item: item, color: color)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }
}

struct DashboardBirthdayRowView: View {
    let item: DashboardBirthdayDTO
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 40, height: 40)

                Image(systemName: item.status == "today" ? "gift.fill" : "person.crop.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.caption)

                    Text(classAndAgeText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(item.timingText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.10))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private var classAndAgeText: String {
        if let ageText = item.ageText {
            return "\(item.displayClassName) · \(ageText)"
        }

        return item.displayClassName
    }
}

struct UnreadBadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption2)
                .fontWeight(.black)
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 6 : 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(AppTheme.danger)
                .clipShape(Capsule())
                .shadow(color: AppTheme.danger.opacity(0.35), radius: 5, x: 0, y: 2)
                .accessibilityLabel("Непрочитанных: \(count)")
        }
    }
}