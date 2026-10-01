import SwiftUI
import SchoolAPIClient

enum MainTabSelection: Hashable {
    case dashboard
    case diary
    case homework
    case finance
    case messages
    case schedule
    case teacher
    case menu
    case health
    case admin
    case profile
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var promoViewModel = CommunityPromoViewModel()
    @State private var didProcessPendingPush = false
    @State private var selectedTab: MainTabSelection = .dashboard
    @State private var showAIChat = false

    private var selectedTabBinding: Binding<MainTabSelection> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab {
                    appState.bumpTabReselectToken(for: newValue)
                }

                selectedTab = newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: selectedTabBinding) {
                    if appState.isAdmin {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        if appState.canUseFinance {
                            themedTab {
                                FinanceView()
                            }
                            .tabItem {
                                Label("Финансы", systemImage: "creditcard.fill")
                            }
                            .tabUnreadBadge(appState.unreadNotificationsCount(for: "finance"))
                            .tag(MainTabSelection.finance)
                        }

                        themedTab {
                            MessagesView()
                        }
                        .tabItem {
                            Label("Сообщения", systemImage: "envelope.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "messages"))
                        .tag(MainTabSelection.messages)

                        themedTab {
                            AdminView()
                        }
                        .tabItem {
                            Label("Админка", systemImage: "gearshape.2.fill")
                        }
                        .tag(MainTabSelection.admin)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    } else if appState.isManager {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        if appState.canUseFinance {
                            themedTab {
                                FinanceView()
                            }
                            .tabItem {
                                Label("Финансы", systemImage: "creditcard.fill")
                            }
                            .tabUnreadBadge(appState.unreadNotificationsCount(for: "finance"))
                            .tag(MainTabSelection.finance)
                        }

                        themedTab {
                            SchoolMenuView()
                        }
                        .tabItem {
                            Label("Меню", systemImage: "fork.knife.circle.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "menu"))
                        .tag(MainTabSelection.menu)

                        themedTab {
                            MessagesView()
                        }
                        .tabItem {
                            Label("Сообщения", systemImage: "envelope.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "messages"))
                        .tag(MainTabSelection.messages)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    } else if appState.isCook {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        themedTab {
                            SchoolMenuView()
                        }
                        .tabItem {
                            Label("Меню", systemImage: "fork.knife.circle.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "menu"))
                        .tag(MainTabSelection.menu)

                        themedTab {
                            HealthView()
                        }
                        .tabItem {
                            Label("Здоровье", systemImage: "heart.text.square.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "health"))
                        .tag(MainTabSelection.health)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    } else if appState.isTeacher {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        themedTab {
                            TeacherCabinetView()
                        }
                        .tabItem {
                            Label("Учителю", systemImage: "person.text.rectangle.fill")
                        }
                        .tag(MainTabSelection.teacher)

                        themedTab {
                            ScheduleView()
                        }
                        .tabItem {
                            Label("Расписание", systemImage: "calendar")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "schedule"))
                        .tag(MainTabSelection.schedule)

                        themedTab {
                            MessagesView()
                        }
                        .tabItem {
                            Label("Сообщения", systemImage: "envelope.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "messages"))
                        .tag(MainTabSelection.messages)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    } else if appState.isParent {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        themedTab {
                            DiaryView()
                        }
                        .tabItem {
                            Label("Дневник", systemImage: "book.closed.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "diary"))
                        .tag(MainTabSelection.diary)

                        themedTab {
                            HomeworkView()
                        }
                        .tabItem {
                            Label("Домашка", systemImage: "pencil.and.list.clipboard")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "homework"))
                        .tag(MainTabSelection.homework)

                        themedTab {
                            SchoolMenuView()
                        }
                        .tabItem {
                            Label("Меню", systemImage: "fork.knife.circle.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "menu"))
                        .tag(MainTabSelection.menu)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    } else {
                        themedTab {
                            DashboardView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house.fill")
                        }
                        .tag(MainTabSelection.dashboard)

                        themedTab {
                            DiaryView()
                        }
                        .tabItem {
                            Label("Дневник", systemImage: "book.closed.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "diary"))
                        .tag(MainTabSelection.diary)

                        themedTab {
                            HomeworkView()
                        }
                        .tabItem {
                            Label("Домашка", systemImage: "pencil.and.list.clipboard")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "homework"))
                        .tag(MainTabSelection.homework)

                        themedTab {
                            MessagesView()
                        }
                        .tabItem {
                            Label("Сообщения", systemImage: "envelope.fill")
                        }
                        .tabUnreadBadge(appState.unreadNotificationsCount(for: "messages"))
                        .tag(MainTabSelection.messages)

                        themedTab {
                            ProfileView()
                        }
                        .tabItem {
                            Label("Профиль", systemImage: "person.circle.fill")
                        }
                        .tag(MainTabSelection.profile)
                    }
                }


                if shouldShowAIFloatingButton {
                    aiFloatingButton
                        .padding(.trailing, 18)
                        .padding(.bottom, 86)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationDestination(isPresented: $showAIChat) {
                AIChatView()
            }
            .navigationDestination(item: $appState.pushRoute) { route in
                pushDestination(route)
                    .onAppear {
                        #if DEBUG
                        print("PUSH DESTINATION APPEARED:", route.sectionKey)
                        #endif
                    }
                    .task {
                        await appState.markPushNotificationReadIfNeeded(route.notificationID)
                        await appState.markNotificationsReadForRoute(route)
                    }
            }
        }
        .tint(AppTheme.control)
        .appScreenBackground()
        .preferredColorScheme(.light)
        .onAppear {
            configureGlobalTheme()
        }
        .task {
            await appState.refreshParentLinkedStudentsContextIfNeeded()
            await promoViewModel.forceCheckPromo(api: appState.api)

            if !didProcessPendingPush {
                didProcessPendingPush = true
                try? await Task.sleep(nanoseconds: 700_000_000)
                await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
            }

            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapStored)) { _ in
            processPendingPushAfterDelay()
        }
        .onChange(of: appState.currentUser?.id) {
            Task {
                await promoViewModel.forceCheckPromo(api: appState.api)
                await appState.refreshUnreadNotificationsBySection()
            }
        }
        .onChange(of: selectedTab) {
            Task {
                await appState.refreshParentLinkedStudentsContextIfNeeded()
            }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            Task {
                await appState.refreshParentLinkedStudentsContextIfNeeded()
                await appState.registerPushNotificationsIfNeeded()
                await promoViewModel.forceCheckPromo(api: appState.api)
                await appState.refreshUnreadNotificationsBySection()
            }
        }
        .fullScreenCover(item: $promoViewModel.promoToShow) { promo in
            CommunityPromoModalView(promo: promo) {
                promoViewModel.promoToShow = nil

                Task {
                    await promoViewModel.markImpression(
                        api: appState.api,
                        promo: promo
                    )
                }
            }
        }
    }

    private var shouldShowAIFloatingButton: Bool {
        selectedTab == .dashboard
        && (
            appState.isTeacher
            || appState.isAdmin
            || appState.isManager
        )
    }

    private var aiFloatingButton: some View {
        Button {
            showAIChat = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))

                Text("ИИ")
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppTheme.buttonGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: AppTheme.primaryDark.opacity(0.34), radius: 16, x: 0, y: 8)
        }
        .accessibilityLabel("Открыть ИИ-помощника")
    }

    private func processPendingPushAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task { @MainActor in
                await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
                await appState.refreshUnreadNotificationsBySection()
            }
        }
    }

    @ViewBuilder
    private func pushDestination(_ route: PushRoute) -> some View {
        switch route {
        case .diary:
            DiaryView()

        case .homework:
            HomeworkView()

        case .messages:
            MessagesView()

        case .events:
            EventsView()

        case .finance:
            FinanceView()

        case .health:
            HealthView()

        case .schedule:
            ScheduleView()

        case .documents:
            DocumentsView()

        case .menu:
            SchoolMenuView()

        case .textbooks:
            TextbooksView()

        case .portfolio:
            PortfolioView()

        case .clubs:
            ClubsView()

        case .community:
            CommunityView()

        case .notifications:
            NotificationsView()
        }
    }

    @ViewBuilder
    private func themedTab<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            AppTheme.mainGradient
                .ignoresSafeArea()

            content()
                .tint(AppTheme.control)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .appNavigationStyle()
        }
    }

    private func configureGlobalTheme() {
        configureTabBarAppearance()
        configureNavigationAppearance()
        configureTableAppearance()
        configureSearchBarAppearance()
        configureSegmentedControlAppearance()
        configurePageControlAppearance()
        configureRefreshControlAppearance()
        configureSwitchAppearance()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.card)
        appearance.shadowColor = UIColor(AppTheme.border.opacity(0.75))

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.control)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.control),
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.muted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.muted),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        appearance.inlineLayoutAppearance.selected.iconColor = UIColor(AppTheme.control)
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.control),
            .font: UIFont.systemFont(ofSize: 12, weight: .bold)
        ]

        appearance.inlineLayoutAppearance.normal.iconColor = UIColor(AppTheme.muted)
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.muted),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]

        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(AppTheme.control)
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.control),
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor(AppTheme.muted)
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.muted),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AppTheme.control)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.muted)
    }

    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.sidebar)
        appearance.shadowColor = UIColor(AppTheme.border.opacity(0.65))

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.heading),
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]

        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.heading),
            .font: UIFont.systemFont(ofSize: 24, weight: .black)
        ]

        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.heading),
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        buttonAppearance.highlighted.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.primaryDark),
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        buttonAppearance.disabled.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.muted).withAlphaComponent(0.45),
            .font: UIFont.systemFont(ofSize: 16, weight: .regular)
        ]

        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance

            if #unavailable(iOS 26.0) {
                appearance.doneButtonAppearance = buttonAppearance
            }

        UINavigationBar.appearance().prefersLargeTitles = false
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.heading)
    }

    private func configureTableAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableView.appearance().separatorColor = UIColor(AppTheme.border.opacity(0.55))

        UITableViewCell.appearance().backgroundColor = .clear
        UITableViewCell.appearance().contentView.backgroundColor = .clear
        UITableViewCell.appearance().selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = UIColor(AppTheme.primarySoft.opacity(0.35))
            return view
        }()

        UICollectionView.appearance().backgroundColor = .clear
        UIScrollView.appearance().backgroundColor = .clear
    }

    private func configureSearchBarAppearance() {
        let searchTextColor = UIColor(AppTheme.text)
        let placeholderColor = UIColor(AppTheme.muted)
        let iconColor = UIColor(AppTheme.control)
        let fieldBackgroundColor = UIColor(AppTheme.cardSoft)
        let barTintColor = UIColor(AppTheme.sidebar)

        UISearchBar.appearance().tintColor = UIColor(AppTheme.control)
        UISearchBar.appearance().barTintColor = barTintColor
        UISearchBar.appearance().backgroundColor = UIColor.clear
        UISearchBar.appearance().searchTextField.backgroundColor = fieldBackgroundColor
        UISearchBar.appearance().searchTextField.textColor = searchTextColor
        UISearchBar.appearance().searchTextField.tintColor = UIColor(AppTheme.control)
        UISearchBar.appearance().searchTextField.leftView?.tintColor = iconColor

        UISearchBar.appearance().searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Поиск",
            attributes: [
                .foregroundColor: placeholderColor
            ]
        )

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = fieldBackgroundColor
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = searchTextColor
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = UIColor(AppTheme.control)
    }

    private func configureSegmentedControlAppearance() {
        let selectedBackground = UIColor(AppTheme.primaryDark)
        let normalBackground = UIColor(AppTheme.primarySoft)
        let selectedText = UIColor.white
        let normalText = UIColor(AppTheme.heading)

        UISegmentedControl.appearance().selectedSegmentTintColor = selectedBackground
        UISegmentedControl.appearance().backgroundColor = normalBackground
        UISegmentedControl.appearance().tintColor = selectedBackground

        UISegmentedControl.appearance().setTitleTextAttributes(
            [
                .foregroundColor: normalText,
                .font: UIFont.systemFont(ofSize: 13, weight: .bold)
            ],
            for: .normal
        )

        UISegmentedControl.appearance().setTitleTextAttributes(
            [
                .foregroundColor: selectedText,
                .font: UIFont.systemFont(ofSize: 13, weight: .black)
            ],
            for: .selected
        )
    }

    private func configurePageControlAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppTheme.control)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppTheme.primarySoft)
    }

    private func configureRefreshControlAppearance() {
        UIRefreshControl.appearance().tintColor = UIColor(AppTheme.control)
    }

    private func configureSwitchAppearance() {
        UISwitch.appearance().onTintColor = UIColor(AppTheme.primaryDark)
        UISwitch.appearance().thumbTintColor = UIColor(AppTheme.card)
    }
}

private extension View {
    @ViewBuilder
    func tabUnreadBadge(_ count: Int) -> some View {
        if count > 0 {
            self.badge(count)
        } else {
            self
        }
    }
}