import SwiftUI
import SchoolAPIClient

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var promoViewModel = CommunityPromoViewModel()

    var body: some View {
        NavigationStack {
            TabView {
                ProfileView()
                    .tabItem {
                        Label("Профиль", systemImage: "person.circle")
                    }

                DashboardView()
                    .tabItem {
                        Label("Главная", systemImage: "house")
                    }

                SettingsView()
                    .tabItem {
                        Label("Настройки", systemImage: "gear")
                    }
            }
            .navigationDestination(item: $appState.pushRoute) { route in
                pushDestination(route)
            }
        }
        .task {
            await promoViewModel.checkPromoForCurrentUser(
                api: appState.api,
                userID: appState.currentUser?.id
            )
        }
        .onChange(of: appState.currentUser?.id) {
            Task {
                await promoViewModel.checkPromoForCurrentUser(
                    api: appState.api,
                    userID: appState.currentUser?.id
                )
            }
        }
        .onChange(of: appState.isAuthenticated) {
            if !appState.isAuthenticated {
                promoViewModel.resetCheckedUser()
            }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            Task {
                await promoViewModel.checkPromoForCurrentUser(
                    api: appState.api,
                    userID: appState.currentUser?.id
                )
            }
        }
        .sheet(item: $promoViewModel.promoToShow) { promo in
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
}

//
//  MainView.swift
//  scapp
//
//  Created by pavel antciferov on 21.05.2026.
//