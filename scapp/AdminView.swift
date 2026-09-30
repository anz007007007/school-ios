import SwiftUI

struct AdminView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.control)

                        Text("Администрирование")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.heading)

                        Text("Раздел управления пользователями, классами, предметами и расписанием.")
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.vertical)
                }

                Section("Управление") {
                    NavigationLink {
                        AdminUsersView()
                    } label: {
                        Label("Пользователи", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        AdminClassesView()
                    } label: {
                        Label("Классы", systemImage: "rectangle.3.group.fill")
                    }

                    NavigationLink {
                        AdminStudentsView()
                    } label: {
                        Label("Ученики", systemImage: "graduationcap.fill")
                    }

                    NavigationLink {
                        AdminTeachersView()
                    } label: {
                        Label("Учителя", systemImage: "person.badge.key.fill")
                    }

                    NavigationLink {
                        AdminParentsView()
                    } label: {
                        Label("Родители", systemImage: "figure.2.and.child.holdinghands")
                    }

                    NavigationLink {
                        AdminSubjectsView()
                    } label: {
                        Label("Предметы", systemImage: "books.vertical.fill")
                    }

                    NavigationLink {
                        TextbooksView()
                    } label: {
                        Label("Учебники", systemImage: "book.closed.fill")
                    }

                    NavigationLink {
                        AdminGradeTypesView()
                    } label: {
                        Label("Типы оценок", systemImage: "star.circle.fill")
                    }

                    NavigationLink {
                        AdminScheduleView()
                    } label: {
                        Label("Расписание", systemImage: "calendar")
                    }

                    NavigationLink {
                        AdminTermsView()
                    } label: {
                        Label("Учебные периоды", systemImage: "calendar.badge.clock")
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Админка")
        }
    }
}

struct AdminPlaceholderView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer.fill",
            description: Text("Этот раздел подключим к API следующим шагом.")
        )
        .navigationTitle(title)
    }
}