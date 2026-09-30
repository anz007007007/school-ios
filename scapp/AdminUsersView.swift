import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminUsersViewModel()

    @State private var showCreateUser = false
    @State private var selectedUserForEdit: AdminUserDTO?

    var body: some View {
        List {
            if !viewModel.users.isEmpty {
                Section {
                    statsView
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Picker("Фильтр", selection: $viewModel.selectedFilter) {
                    ForEach(AdminUsersViewModel.AdminUsersFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Пользователи")
        .searchable(text: $viewModel.searchText, prompt: "Поиск")
        .refreshable {
            await viewModel.loadUsers(api: appState.api)
        }
        .task {
            if viewModel.users.isEmpty {
                await viewModel.loadUsers(api: appState.api)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateUser = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadUsers(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateUser) {
            AdminCreateUserView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedUserForEdit) { user in
            AdminEditUserView(viewModel: viewModel, user: user)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await viewModel.loadUsers(api: appState.api)
                        }
                    } label: {
                        Text("Повторить")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredUsers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Пользователи не найдены")
                        .font(.headline)

                    Text("Попробуйте изменить поиск или фильтр.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredUsers) { user in
                    Button {
                        selectedUserForEdit = user
                    } label: {
                        AdminUserRowView(user: user)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.users.filter { $0.is_active }.count
        let inactiveCount = viewModel.users.filter { !$0.is_active }.count

        return HStack(spacing: 12) {
            AdminUsersStatCard(
                title: "Всего",
                value: "\(viewModel.users.count)",
                color: .blue,
                systemImage: "person.3.fill"
            )

            AdminUsersStatCard(
                title: "Активные",
                value: "\(activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )

            AdminUsersStatCard(
                title: "Неактивные",
                value: "\(inactiveCount)",
                color: .red,
                systemImage: "xmark.circle.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminUserRowView: View {
    let user: AdminUserDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(user.is_active ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .foregroundStyle(user.is_active ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.full_name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("@\(user.login)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(user.role_name)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if user.is_active {
                    Text("Активен")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else {
                    Text("Отключен")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch user.role_code {
        case "admin":
            return "person.badge.key.fill"
        case "teacher":
            return "person.fill.checkmark"
        case "student":
            return "graduationcap.fill"
        case "parent":
            return "figure.2.and.child.holdinghands"
        case "cook":
            return "fork.knife.circle.fill"
        case "manager":
            return "briefcase.fill"
        default:
            return "person.fill"
        }
    }
}

struct AdminUsersStatCard: View {
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

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}