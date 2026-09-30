import SwiftUI

struct ClubsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ClubsViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()

    @State private var selectedClub: ClubDTO?
    @State private var editingClub: ClubDTO?
    @State private var managingStudentsClub: ClubDTO?
    @State private var enrollingClub: ClubDTO?
    @State private var composingTeacherContact: MessageContactDTO?

    @State private var isShowingCreateForm = false
    @State private var clubToDelete: ClubDTO?
    @State private var isShowingDeleteConfirmation = false

    @State private var unenrollRequest: ClubUnenrollRequest?
    @State private var isShowingUnenrollConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    }
                }

                if !viewModel.clubs.isEmpty {
                    Section {
                        statsView
                    }

                    if !viewModel.timeConflicts.isEmpty {
                        Section("Пересечения") {
                            conflictsView
                        }
                    }
                }

                timelineSection
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Кружки")
            .searchable(text: $viewModel.searchText, prompt: "Поиск кружка")
            .preferredColorScheme(.light)
            .onSubmit(of: .search) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }
            .refreshable {
                await viewModel.loadInitialData(api: appState.api)
            }
            .task {
                if viewModel.clubs.isEmpty {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if appState.canManageClubs {
                        Button {
                            isShowingCreateForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    Button {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedClub) { club in
                ClubDetailView(
                    club: club,
                    students: viewModel.filterStudents,
                    weekdayTitle: viewModel.weekdayTitle(club.weekday),
                    statusTitle: viewModel.statusTitle(club.status),
                    paymentTypeTitle: viewModel.paymentTypeTitle(club.paymentTypeValue),
                    canManage: appState.canManageClubs,
                    canManageEnrollment: appState.canSelfEnrollClubs,
                    canMessageTeacher: appState.canSendMessages,
                    onMessageTeacher: {
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            composingTeacherContact = teacherContact(for: club)
                        }
                    },
                    onCallTeacher: {
                        callTeacher(club)
                    },
                    onEnroll: {
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            enrollingClub = club
                        }
                    },
                    onUnenroll: { student in
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            unenrollRequest = ClubUnenrollRequest(
                                club: club,
                                student: student
                            )
                            isShowingUnenrollConfirmation = true
                        }
                    },
                    onManageStudents: {
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            managingStudentsClub = club
                        }
                    },
                    onEdit: {
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            editingClub = club
                        }
                    },
                    onDelete: {
                        selectedClub = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            clubToDelete = club
                            isShowingDeleteConfirmation = true
                        }
                    }
                )
            }
            .sheet(item: $managingStudentsClub) { club in
                ClubStudentsManagementView(
                    club: club,
                    viewModel: viewModel
                )
                .environmentObject(appState)
            }
            .sheet(item: $enrollingClub) { club in
                ClubEnrollView(
                    club: club,
                    students: viewModel.filterStudents,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onEnroll: { studentID in
                        Task { @MainActor in
                            let success = await viewModel.enrollToClub(
                                api: appState.api,
                                clubID: club.id,
                                studentID: studentID
                            )

                            if success {
                                enrollingClub = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingCreateForm) {
                ClubFormView(
                    mode: .create,
                    club: nil,
                    teachers: viewModel.filterTeachers,
                    initialTeacherID: 0,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = ClubFormData(
                            name: String(formData.name),
                            description: String(formData.description),
                            weekdayIDs: Array(formData.weekdayIDs),
                            startTime: String(formData.startTime),
                            endTime: String(formData.endTime),
                            capacity: formData.capacity,
                            priceAmount: String(formData.priceAmount),
                            paymentType: String(formData.paymentType),
                            teacherID: formData.teacherID,
                            status: String(formData.status)
                        )

                        Task { @MainActor in
                            _ = await viewModel.createClub(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingClub) { club in
                ClubFormView(
                    mode: .edit,
                    club: club,
                    teachers: viewModel.filterTeachers,
                    initialTeacherID: viewModel.teacherID(for: club),
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = ClubFormData(
                            name: String(formData.name),
                            description: String(formData.description),
                            weekdayIDs: Array(formData.weekdayIDs),
                            startTime: String(formData.startTime),
                            endTime: String(formData.endTime),
                            capacity: formData.capacity,
                            priceAmount: String(formData.priceAmount),
                            paymentType: String(formData.paymentType),
                            teacherID: formData.teacherID,
                            status: String(formData.status)
                        )

                        Task { @MainActor in
                            _ = await viewModel.updateClub(
                                api: appState.api,
                                clubID: club.id,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $composingTeacherContact) { contact in
                MessageComposeView(
                    mode: .single,
                    contacts: [contact],
                    initialRecipientID: contact.id,
                    isSaving: messagesViewModel.isSaving,
                    errorMessage: messagesViewModel.errorMessage,
                    onSendSingle: { formData in
                        Task { @MainActor in
                            _ = await messagesViewModel.sendMessage(
                                api: appState.api,
                                formData: formData
                            )
                        }
                    },
                    onSendBulk: { _ in }
                )
            }
            .confirmationDialog(
                "Удалить кружок?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let clubToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deleteClub(
                            api: appState.api,
                            club: clubToDelete
                        )

                        self.clubToDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    clubToDelete = nil
                }
            } message: {
                if let clubToDelete {
                    Text("Кружок «\(clubToDelete.name)» будет удалён без возможности восстановления.")
                }
            }
            .confirmationDialog(
                "Выписать ребёнка из кружка?",
                isPresented: $isShowingUnenrollConfirmation,
                titleVisibility: .visible
            ) {
                Button("Выписать", role: .destructive) {
                    guard let unenrollRequest else {
                        return
                    }

                    Task {
                        _ = await viewModel.unenrollFromClub(
                            api: appState.api,
                            clubID: unenrollRequest.club.id,
                            studentID: unenrollRequest.student.id
                        )

                        self.unenrollRequest = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    unenrollRequest = nil
                }
            } message: {
                if let unenrollRequest {
                    Text("Ребёнок «\(unenrollRequest.student.student_name)» будет выписан из кружка «\(unenrollRequest.club.name)».")
                }
            }
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            Picker("День", selection: $viewModel.selectedWeekday) {
                ForEach(ClubsViewModel.WeekdayFilter.allCases) { day in
                    Text(day.rawValue).tag(day)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedWeekday) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            Picker("Статус", selection: $viewModel.selectedStatus) {
                ForEach(ClubsViewModel.ClubStatusFilter.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .onChange(of: viewModel.selectedStatus) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            if viewModel.isLoadingFilters {
                HStack {
                    Spacer()
                    ProgressView("Загрузка фильтров...")
                    Spacer()
                }
            }

            if !viewModel.filterTeachers.isEmpty {
                Picker("Преподаватель", selection: $viewModel.selectedTeacherID) {
                    Text("Все преподаватели").tag(0)

                    ForEach(viewModel.filterTeachers) { teacher in
                        Text(teacher.teacher_name).tag(teacher.id)
                    }
                }
                .onChange(of: viewModel.selectedTeacherID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }
            }

            if !viewModel.filterStudents.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    Text("Все ученики").tag(0)

                    ForEach(viewModel.filterStudents) { student in
                        Text(student.student_name).tag(student.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }
            }

            Button {
                viewModel.searchText = ""

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            } label: {
                Label("Сбросить поиск", systemImage: "xmark.circle")
            }
            .disabled(viewModel.searchText.isEmpty)
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            ClubStatCard(
                title: "Кружков",
                value: "\(viewModel.filteredClubs.count)",
                color: .blue,
                systemImage: "star.circle.fill"
            )

            ClubStatCard(
                title: "Активные",
                value: "\(viewModel.activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )

            ClubStatCard(
                title: "Записей",
                value: "\(viewModel.totalEnrolled)",
                color: .purple,
                systemImage: "person.3.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var conflictsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Кружки в одно и то же время", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)

            ForEach(viewModel.timeConflicts) { conflict in
                VStack(alignment: .leading, spacing: 6) {
                    Text(conflict.key)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(conflict.clubs) { club in
                        HStack {
                            Circle()
                                .fill(clubColor(club))
                                .frame(width: 8, height: 8)

                            Text(club.name)
                                .font(.caption)

                            Spacer()

                            Text(club.teacher_name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Пересечения считаются по одному дню недели и одинаковому времени. Если выбран ученик или преподаватель, список покажет пересечения уже в рамках фильтра.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var timelineSection: some View {
        Section("Таймлайн") {
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

                    Button("Повторить") {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.groupedByDay.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Кружков нет")
                        .font(.headline)

                    Text("По выбранным фильтрам кружки не найдены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if appState.canManageClubs {
                        Button {
                            isShowingCreateForm = true
                        } label: {
                            Label("Добавить кружок", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.groupedByDay) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.weekdayTitle(group.weekday))
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)

                        ForEach(Array(group.clubs.enumerated()), id: \.element.id) { index, club in
                            Button {
                                selectedClub = club
                            } label: {
                                ClubTimelineRowView(
                                    club: club,
                                    weekdayShortTitle: viewModel.shortWeekdayTitle(club.weekday),
                                    statusTitle: viewModel.statusTitle(club.status),
                                    paymentTypeTitle: viewModel.paymentTypeTitle(club.paymentTypeValue),
                                    color: clubColor(club),
                                    showLine: index != group.clubs.count - 1
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if canShowEnrollmentActions(for: club) {
                                    if hasAvailableChildrenToEnroll(in: club) {
                                        Button {
                                            enrollingClub = club
                                        } label: {
                                            Label("Записать", systemImage: "person.badge.plus")
                                        }
                                        .tint(.green)
                                    }

                                    if hasChildrenToUnenroll(from: club) {
                                        Button {
                                            if let student = enrolledChildren(in: club).first {
                                                unenrollRequest = ClubUnenrollRequest(
                                                    club: club,
                                                    student: student
                                                )
                                                isShowingUnenrollConfirmation = true
                                            }
                                        } label: {
                                            Label("Выписать", systemImage: "person.crop.circle.badge.minus")
                                        }
                                        .tint(.red)
                                    }
                                }

                                if appState.canManageClubs {
                                    Button(role: .destructive) {
                                        clubToDelete = club
                                        isShowingDeleteConfirmation = true
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }

                                    Button {
                                        editingClub = club
                                    } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button {
                                        managingStudentsClub = club
                                    } label: {
                                        Label("Ученики", systemImage: "person.3.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func canShowEnrollmentActions(for club: ClubDTO) -> Bool {
        appState.canSelfEnrollClubs
        && club.status == "active"
        && !viewModel.filterStudents.isEmpty
    }

    private func hasAvailableChildrenToEnroll(in club: ClubDTO) -> Bool {
        canShowEnrollmentActions(for: club)
        && !club.isFull
        && !availableChildrenToEnroll(in: club).isEmpty
    }

    private func hasChildrenToUnenroll(from club: ClubDTO) -> Bool {
        canShowEnrollmentActions(for: club)
        && !enrolledChildren(in: club).isEmpty
    }

    private func availableChildrenToEnroll(in club: ClubDTO) -> [ClubFilterStudentDTO] {
        viewModel.filterStudents
            .filter { !club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private func enrolledChildren(in club: ClubDTO) -> [ClubFilterStudentDTO] {
        viewModel.filterStudents
            .filter { club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private func canEnroll(in club: ClubDTO) -> Bool {
        hasAvailableChildrenToEnroll(in: club)
    }

    private func clubColor(_ club: ClubDTO) -> Color {
        if club.status == "archived" {
            return .gray
        }

        if club.status == "draft" {
            return .orange
        }

        if club.isFull {
            return .red
        }

        return .green
    }

    private func teacherContact(for club: ClubDTO) -> MessageContactDTO? {
        guard let teacherUserID = club.resolvedTeacherUserID else {
            return nil
        }

        return MessageContactDTO(
            id: teacherUserID,
            full_name: club.teacher_name,
            role_code: "teacher",
            role_name: "Учитель",
            context_label: club.name,
            phone: club.resolvedTeacherPhone
        )
    }

    private func callTeacher(_ club: ClubDTO) {
        guard let phone = club.resolvedTeacherPhone else {
            return
        }

        let digits = phone.filter { $0.isNumber || $0 == "+" }

        guard !digits.isEmpty,
              let url = URL(string: "tel://\(digits)") else {
            return
        }

        UIApplication.shared.open(url)
    }
}

struct ClubUnenrollRequest: Identifiable {
    let id = UUID()
    let club: ClubDTO
    let student: ClubFilterStudentDTO
}

struct ClubTimelineRowView: View {
    let club: ClubDTO
    let weekdayShortTitle: String
    let statusTitle: String
    let paymentTypeTitle: String
    let color: Color
    let showLine: Bool

    private var cleanDescription: String {
        (club.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 38, height: 38)

                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                }

                if showLine {
                    Rectangle()
                        .fill(color.opacity(0.25))
                        .frame(width: 2, height: 72)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(club.start_time)–\(club.end_time)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text(weekdayShortTitle)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .foregroundStyle(color)
                        .clipShape(Capsule())

                    Spacer()

                    Text(statusTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(club.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if !cleanDescription.isEmpty {
                    Text(cleanDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Label(club.teacher_name, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                capacityView
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.vertical, 4)
    }

    private var capacityView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(club.enrolled_count)/\(club.capacity)", systemImage: "person.3.fill")

                if club.isFull {
                    Text("мест нет")
                        .foregroundStyle(.red)
                } else {
                    Text("свободно: \(club.availableSpots)")
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(club.price_amount)
                        .foregroundStyle(.secondary)

                    Text(paymentTypeTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            ProgressView(value: progressValue)
                .tint(club.isFull ? .red : .green)
        }
    }

    private var progressValue: Double {
        guard club.capacity > 0 else {
            return 0
        }

        return min(Double(club.enrolled_count) / Double(club.capacity), 1)
    }
}

struct ClubDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let club: ClubDTO
    let students: [ClubFilterStudentDTO]
    let weekdayTitle: String
    let statusTitle: String
    let paymentTypeTitle: String
    let canManage: Bool
    let canManageEnrollment: Bool
    let canMessageTeacher: Bool
    let onMessageTeacher: () -> Void
    let onCallTeacher: () -> Void
    let onEnroll: () -> Void
    let onUnenroll: (ClubFilterStudentDTO) -> Void
    let onManageStudents: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var cleanDescription: String {
        (club.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var enrolledChildren: [ClubFilterStudentDTO] {
        students
            .filter { club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private var availableChildren: [ClubFilterStudentDTO] {
        students
            .filter { !club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private var canShowEnrollButton: Bool {
        canManageEnrollment
        && club.status == "active"
        && !club.isFull
        && !availableChildren.isEmpty
    }

    private var canShowUnenrollActions: Bool {
        canManageEnrollment
        && club.status == "active"
        && !enrolledChildren.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(statusTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.12))
                                .foregroundStyle(statusColor)
                                .clipShape(Capsule())

                            Spacer()

                            if club.isFull {
                                Text("Мест нет")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.danger)
                            }
                        }

                        Text(club.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.heading)

                        if !cleanDescription.isEmpty {
                            Text(cleanDescription)
                                .font(.body)
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.leading)
                        }

                        Label("\(weekdayTitle), \(club.start_time)–\(club.end_time)", systemImage: "calendar")
                            .foregroundStyle(AppTheme.muted)

                        Label(club.teacher_name, systemImage: "person.fill")
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.vertical)
                }

                teacherContactSection

                Section("Заполняемость") {
                    LabeledContent("Записано", value: "\(club.enrolled_count)")
                    LabeledContent("Вместимость", value: "\(club.capacity)")
                    LabeledContent("Свободно", value: "\(club.availableSpots)")

                    ProgressView(value: progressValue)
                        .tint(club.isFull ? AppTheme.danger : AppTheme.success)
                }

                Section("Оплата") {
                    LabeledContent("Тип оплаты", value: paymentTypeTitle)
                    LabeledContent("Стоимость", value: club.price_amount)
                }

                enrollmentSection

                if canManage {
                    Section("Управление") {
                        Button {
                            onManageStudents()
                        } label: {
                            Label("Ученики кружка", systemImage: "person.3.fill")
                        }

                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }

                Section("Система") {
                    LabeledContent("ID кружка", value: "\(club.id)")
                    LabeledContent("День недели", value: "\(club.weekday)")
                    LabeledContent("Статус", value: club.status)
                    LabeledContent("Тип оплаты", value: club.paymentTypeValue ?? "Не указан")
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Кружок")
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

    @ViewBuilder
    private var teacherContactSection: some View {
        Section("Преподаватель") {
            Label(club.teacher_name, systemImage: "person.fill")

            if canMessageTeacher, club.resolvedTeacherUserID != nil {
                Button {
                    onMessageTeacher()
                } label: {
                    Label("Написать сообщение", systemImage: "message.fill")
                }
            }

            if let phone = club.resolvedTeacherPhone {
                Button {
                    onCallTeacher()
                } label: {
                    Label("Позвонить: \(phone)", systemImage: "phone.fill")
                }
            } else {
                Text("Телефон преподавателя не указан")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    @ViewBuilder
    private var enrollmentSection: some View {
        if canManageEnrollment {
            Section("Запись ребёнка") {
                if !enrolledChildren.isEmpty {
                    ForEach(enrolledChildren) { student in
                        HStack {
                            Label(student.student_name, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)

                            Spacer()

                            if club.status == "active" {
                                Button(role: .destructive) {
                                    onUnenroll(student)
                                } label: {
                                    Text("Выписать")
                                }
                            }
                        }
                    }
                }

                if canShowEnrollButton {
                    Button {
                        onEnroll()
                    } label: {
                        Label("Записать ребёнка", systemImage: "person.badge.plus")
                    }
                } else if club.status != "active" {
                    Label("Запись недоступна: кружок не активен", systemImage: "lock.fill")
                        .foregroundStyle(AppTheme.muted)
                } else if club.isFull && availableChildren.isEmpty && !enrolledChildren.isEmpty {
                    Label("Все ваши дети уже записаны. Свободных мест нет.", systemImage: "person.3.sequence.fill")
                        .foregroundStyle(AppTheme.muted)
                } else if club.isFull {
                    Label("Свободных мест нет", systemImage: "person.3.sequence.fill")
                        .foregroundStyle(AppTheme.danger)
                } else if availableChildren.isEmpty && !enrolledChildren.isEmpty {
                    Label("Все ваши дети уже записаны в этот кружок", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                } else if students.isEmpty {
                    Label("Дети для записи не найдены", systemImage: "person.fill.questionmark")
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
    }

    private var progressValue: Double {
        guard club.capacity > 0 else {
            return 0
        }

        return min(Double(club.enrolled_count) / Double(club.capacity), 1)
    }

    private var statusColor: Color {
        if club.status == "archived" {
            return .gray
        }

        if club.status == "draft" {
            return AppTheme.warning
        }

        if club.isFull {
            return AppTheme.danger
        }

        return AppTheme.success
    }
}

struct ClubEnrollView: View {
    @Environment(\.dismiss) private var dismiss

    let club: ClubDTO
    let students: [ClubFilterStudentDTO]
    let isSaving: Bool
    let errorMessage: String?
    let onEnroll: (Int) -> Void

    @State private var selectedStudentID: Int = 0
    @State private var validationMessage: String?

    private var availableStudents: [ClubFilterStudentDTO] {
        students
            .filter { !club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private var alreadyEnrolledStudents: [ClubFilterStudentDTO] {
        students
            .filter { club.isStudentAlreadyEnrolled($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    private var selectedStudent: ClubFilterStudentDTO? {
        availableStudents.first { $0.id == selectedStudentID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(club.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.heading)

                    Text("Выберите ребёнка, которого нужно записать в кружок.")
                        .foregroundStyle(AppTheme.muted)
                }

                Section("Ученик") {
                    if availableStudents.isEmpty {
                        Label("Все доступные дети уже записаны в этот кружок.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)

                        if !alreadyEnrolledStudents.isEmpty {
                            ForEach(alreadyEnrolledStudents) { student in
                                Label(student.student_name, systemImage: "person.fill.checkmark")
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                    } else {
                        Picker("Ученик", selection: $selectedStudentID) {
                            Text("Выберите ученика").tag(0)

                            ForEach(availableStudents) { student in
                                Text(student.student_name).tag(student.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if let selectedStudent {
                            Label(selectedStudent.student_name, systemImage: "person.fill")
                                .foregroundStyle(AppTheme.control)
                        } else {
                            Text("Ученик не выбран")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }

                if !alreadyEnrolledStudents.isEmpty {
                    Section("Уже записаны") {
                        ForEach(alreadyEnrolledStudents) { student in
                            Label(student.student_name, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }

                Section("Информация") {
                    LabeledContent("Кружок", value: club.name)
                    LabeledContent("Свободно мест", value: "\(club.availableSpots)")
                    LabeledContent("Записано", value: "\(club.enrolled_count)/\(club.capacity)")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.danger)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                Section {
                    Button {
                        enroll()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Записать ребёнка")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving || selectedStudentID == 0 || club.isFull || availableStudents.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Запись")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .onAppear {
                if selectedStudentID == 0 {
                    selectedStudentID = availableStudents.first?.id ?? 0
                }

                if !availableStudents.contains(where: { $0.id == selectedStudentID }) {
                    selectedStudentID = availableStudents.first?.id ?? 0
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func enroll() {
        validationMessage = nil

        guard selectedStudentID != 0 else {
            validationMessage = "Выберите ученика"
            return
        }

        guard !club.isFull else {
            validationMessage = "В кружке нет свободных мест"
            return
        }

        guard !club.isStudentAlreadyEnrolled(selectedStudentID) else {
            validationMessage = "Этот ребёнок уже записан в кружок"
            return
        }

        onEnroll(selectedStudentID)
    }
}

struct ClubStudentsManagementView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let club: ClubDTO
    @ObservedObject var viewModel: ClubsViewModel

    @State private var selectedStudentID = 0
    @State private var selectedEnrollmentStatus = "active"
    @State private var validationMessage: String?

    private let statuses: [(title: String, value: String)] = [
        ("Записан", "active"),
        ("Ожидает", "pending"),
        ("Пауза", "paused"),
        ("Выбыл", "left")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(club.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(club.enrolled_count)/\(club.capacity) записано")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                addStudentSection

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
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
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                studentsSection
            }
            .navigationTitle("Ученики кружка")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadClubStudents(api: appState.api, clubID: club.id)
                selectedStudentID = viewModel.availableStudentsForClub(club.id).first?.id ?? 0
            }
            .refreshable {
                await viewModel.loadClubStudents(api: appState.api, clubID: club.id)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private var addStudentSection: some View {
        Section("Добавить ученика") {
            let availableStudents = viewModel.availableStudentsForClub(club.id)

            if availableStudents.isEmpty {
                Text("Все доступные ученики уже записаны или список учеников не загружен.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Ученик", selection: $selectedStudentID) {
                    ForEach(availableStudents) { student in
                        Text(student.student_name).tag(student.id)
                    }
                }

                Picker("Статус", selection: $selectedEnrollmentStatus) {
                    ForEach(statuses, id: \.value) { status in
                        Text(status.title).tag(status.value)
                    }
                }

                Button {
                    addStudent()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Label("Добавить в кружок", systemImage: "plus.circle.fill")
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    private var studentsSection: some View {
        Section("Записанные ученики") {
            if viewModel.isLoadingClubStudents {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
            } else {
                let students = viewModel.studentsForClub(club.id)

                if students.isEmpty {
                    Text("В кружок пока никто не записан.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(students) { student in
                        ClubStudentRowView(
                            student: student,
                            statusTitle: viewModel.enrollmentStatusTitle(student.enrollment_status),
                            onStatusChange: { newStatus in
                                Task {
                                    _ = await viewModel.updateClubStudentStatus(
                                        api: appState.api,
                                        clubID: club.id,
                                        studentID: student.student_id,
                                        enrollmentStatus: newStatus
                                    )
                                }
                            },
                            onDelete: {
                                Task {
                                    _ = await viewModel.removeStudentFromClub(
                                        api: appState.api,
                                        clubID: club.id,
                                        studentID: student.student_id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func addStudent() {
        validationMessage = nil

        guard selectedStudentID != 0 else {
            validationMessage = "Выберите ученика"
            return
        }

        Task {
            let success = await viewModel.addStudentToClub(
                api: appState.api,
                clubID: club.id,
                formData: ClubStudentFormData(
                    studentID: selectedStudentID,
                    enrollmentStatus: selectedEnrollmentStatus
                )
            )

            if success {
                selectedStudentID = viewModel.availableStudentsForClub(club.id).first?.id ?? 0
            }
        }
    }
}

struct ClubStudentRowView: View {
    let student: ClubStudentDTO
    let statusTitle: String
    let onStatusChange: (String) -> Void
    let onDelete: () -> Void

    private let statuses: [(title: String, value: String)] = [
        ("Записан", "active"),
        ("Ожидает", "pending"),
        ("Пауза", "paused"),
        ("Выбыл", "left")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.student_name)
                        .font(.headline)

                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
            }

            Picker("Статус", selection: Binding(
                get: { student.enrollment_status },
                set: { newValue in
                    onStatusChange(newValue)
                }
            )) {
                ForEach(statuses, id: \.value) { status in
                    Text(status.title).tag(status.value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch student.enrollment_status {
        case "active":
            return .green
        case "pending":
            return .orange
        case "paused":
            return .blue
        case "left":
            return .red
        default:
            return .secondary
        }
    }
}

struct ClubStatCard: View {
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}