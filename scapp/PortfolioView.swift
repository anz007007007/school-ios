import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SchoolAPIClient

struct PortfolioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PortfolioViewModel()

    @State private var isShowingWebEditInfo = false

    @State private var isShowingReviewSheet = false
    @State private var reviewTitle = ""
    @State private var reviewBody = ""

    var body: some View {
        NavigationStack {
            LoadingErrorView(
                isLoading: viewModel.isLoading && viewModel.portfolio == nil,
                errorMessage: viewModel.errorMessage,
                onRetry: {
                    Task {
                        await viewModel.loadInitial(
                            api: appState.api,
                            roleCode: appState.userRoleCode
                        )
                    }
                }
            ) {
                ScrollView {
                    VStack(spacing: 16) {
                        studentPickerSection

                        if let portfolio = viewModel.portfolio {
                            coverSection(portfolio)
                            ratingSection(portfolio.rating)
                            badgesSection(portfolio.badges)
                            blocksSection(portfolio.blocks)
                            reviewsSection(portfolio.reviews)
                            publicSection(portfolio)
                        } else {
                            emptyState
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refreshPortfolio(api: appState.api)
                }
            }
            .navigationTitle("Портфолио")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView()
                    }

                    if let portfolio = viewModel.portfolio, portfolio.can_review {
                        Button {
                            reviewTitle = ""
                            reviewBody = ""
                            isShowingReviewSheet = true
                        } label: {
                            Image(systemName: "text.bubble.fill")
                        }
                    }

                    if let portfolio = viewModel.portfolio, portfolio.can_edit {
                        Button {
                            isShowingWebEditInfo = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadInitial(
                    api: appState.api,
                    roleCode: appState.userRoleCode
                )
            }
            .alert("Готово", isPresented: successBinding) {
                Button("ОК", role: .cancel) {
                    viewModel.successMessage = nil
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .sheet(isPresented: $isShowingWebEditInfo) {
                PortfolioWebEditInfoView(
                    publicURL: viewModel.portfolio?.public_url,
                    publicToken: viewModel.portfolio?.public_token
                )
            }
            .sheet(isPresented: $isShowingReviewSheet) {
                NavigationStack {
                    Form {
                        Section("Отзыв учителя") {
                            TextField("Заголовок", text: $reviewTitle)

                            TextEditor(text: $reviewBody)
                                .frame(minHeight: 140)
                        }
                    }
                    .navigationTitle("Добавить отзыв")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") {
                                isShowingReviewSheet = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Сохранить") {
                                guard let portfolioId = viewModel.portfolio?.id else {
                                    return
                                }

                                isShowingReviewSheet = false

                                Task {
                                    await viewModel.createTeacherReview(
                                        api: appState.api,
                                        portfolioId: portfolioId,
                                        title: reviewTitle,
                                        body: reviewBody
                                    )
                                }
                            }
                            .disabled(reviewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.successMessage != nil
            },
            set: { newValue in
                if !newValue {
                    viewModel.successMessage = nil
                }
            }
        )
    }

    private var studentPickerSection: some View {
        Group {
            if viewModel.students.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ученик")
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Picker("Ученик", selection: selectedStudentBinding) {
                        ForEach(viewModel.students) { student in
                            Text(studentTitle(student))
                                .tag(Optional(student))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var selectedStudentBinding: Binding<PortfolioStudentDTO?> {
        Binding(
            get: {
                viewModel.selectedStudent
            },
            set: { newValue in
                guard let newValue else {
                    return
                }

                Task {
                    await viewModel.selectStudent(newValue, api: appState.api)
                }
            }
        )
    }

    private func coverSection(_ portfolio: PortfolioDTO) -> some View {
        VStack(spacing: 14) {
            PortfolioAvatarView(urlString: portfolio.avatar_url)

            VStack(spacing: 5) {
                Text(portfolio.student_name)
                    .font(.title2)
                    .fontWeight(.black)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.heading)

                if let className = portfolio.class_name {
                    Text(className)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.control)
                }
            }

            if let title = nonEmpty(portfolio.title) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.text)
            }

            if let tagline = nonEmpty(portfolio.tagline) {
                Text(tagline)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.primaryDark)
            }

            if let summary = nonEmpty(portfolio.summary) {
                Text(summary)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.text)
            }

            HStack(spacing: 8) {
                Label(PortfolioThemes.title(portfolio.theme_code), systemImage: "paintpalette.fill")
                    .font(.caption)
                    .fontWeight(.bold)

                if portfolio.is_public {
                    Label("Публично", systemImage: "link.circle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .foregroundStyle(AppTheme.control)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(themeGradient(portfolio.theme_code))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func ratingSection(_ rating: PortfolioRatingDTO?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Учебный рейтинг", icon: "chart.line.uptrend.xyaxis")

            if let rating, rating.grades_count > 0 {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ratingCard(
                        title: "Средний балл",
                        value: formatGrade(rating.average_grade),
                        subtitle: deltaText(rating.average_delta, suffix: "")
                    )

                    ratingCard(
                        title: "Школа",
                        value: rankText(rank: rating.school_rank, total: rating.school_total),
                        subtitle: rankDeltaText(rating.school_rank_delta)
                    )

                    ratingCard(
                        title: "Класс",
                        value: rankText(rank: rating.class_rank, total: rating.class_total),
                        subtitle: rankDeltaText(rating.class_rank_delta)
                    )

                    ratingCard(
                        title: "Тренд",
                        value: trendTitle(rating.trend),
                        subtitle: "\(rating.grades_count) оценок"
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Средний балл: —")
                    Text("Школа: —")
                    Text("Класс: —")
                    Text("Статус: Нет оценок")
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .portfolioCard()
    }

    private func badgesSection(_ badges: [PortfolioBadgeDTO]) -> some View {
        Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Бейджи", icon: "rosette")

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 130), spacing: 10)
                    ], spacing: 10) {
                        ForEach(badges.sorted { $0.sort_order < $1.sort_order }) { badge in
                            VStack(spacing: 8) {
                                Image(systemName: badge.icon ?? "star.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.control)

                                Text(badge.title)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)

                                if let description = nonEmpty(badge.description) {
                                    Text(description)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.muted)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(AppTheme.primarySoft.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .portfolioCard()
            }
        }
    }

    private func blocksSection(_ blocks: [PortfolioBlockDTO]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Секции", icon: "square.grid.2x2.fill")

            if blocks.isEmpty {
                Text("Пока нет добавленных достижений, проектов или работ.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(groupedBlockTypes(blocks), id: \.self) { type in
                    let items = blocks
                        .filter { $0.block_type == type }
                        .sorted { $0.sort_order < $1.sort_order }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: PortfolioBlockTypes.icon(type))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.control)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text(PortfolioBlockTypes.title(type))
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundStyle(AppTheme.heading)
                        }

                        ForEach(items) { block in
                            PortfolioBlockCard(block: block)
                        }
                    }
                    .padding()
                    .background(AppTheme.primarySoft.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
                    }
                }
            }
        }
        .portfolioCard()
    }

    private func reviewsSection(_ reviews: [PortfolioTeacherReviewDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Отзывы", icon: "text.bubble.fill")

            let visibleReviews = reviews.filter { $0.is_visible }

            if visibleReviews.isEmpty {
                Text("Пока нет отзывов учителей.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(visibleReviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(review.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.heading)

                        Text(review.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.text)

                        HStack {
                            Text(review.teacher_name)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(formatDate(review.created_at))
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    }
                    .padding()
                    .background(AppTheme.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .portfolioCard()
    }

    private func publicSection(_ portfolio: PortfolioDTO) -> some View {
        Group {
            if portfolio.is_public, let publicUrl = nonEmpty(portfolio.public_url) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "Публичная ссылка", icon: "link")

                    Text(publicUrl)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.control)
                        .textSelection(.enabled)

                    ShareLink(item: publicUrl) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .portfolioCard()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.square")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.muted)

            Text("Портфолио не найдено")
                .font(.headline)

            Text("Выберите ученика или повторите загрузку.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .portfolioCard()
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .fontWeight(.black)
            .foregroundStyle(AppTheme.heading)
    }

    private func ratingCard(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundStyle(AppTheme.heading)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.control)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func studentTitle(_ student: PortfolioStudentDTO) -> String {
        if let className = student.class_name {
            return "\(student.student_name), \(className)"
        }

        return student.student_name
    }

    private func groupedBlockTypes(_ blocks: [PortfolioBlockDTO]) -> [String] {
        PortfolioBlockTypes.all.filter { type in
            blocks.contains { $0.block_type == type }
        }
    }

    private func formatGrade(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return String(format: "%.2f", value)
    }

    private func rankText(rank: Int?, total: Int) -> String {
        guard let rank else {
            return "—"
        }

        return "\(rank) из \(total)"
    }

    private func deltaText(_ value: Double?, suffix: String) -> String? {
        guard let value else {
            return nil
        }

        if value > 0 {
            return "+\(String(format: "%.2f", value))\(suffix)"
        }

        if value < 0 {
            return "\(String(format: "%.2f", value))\(suffix)"
        }

        return "без изменений"
    }

    private func rankDeltaText(_ value: Int?) -> String? {
        guard let value else {
            return nil
        }

        if value > 0 {
            return "поднялся на \(value) мест"
        }

        if value < 0 {
            return "опустился на \(abs(value)) мест"
        }

        return "без изменений"
    }

    private func trendTitle(_ trend: String) -> String {
        switch trend {
        case "up":
            return "Вырос"
        case "down":
            return "Снизился"
        case "stable":
            return "Стабильно"
        default:
            return trend
        }
    }

    private func formatDate(_ value: String) -> String {
        AppDateFormatter.dateTime(value)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func themeGradient(_ code: String) -> LinearGradient {
        switch code {
        case PortfolioThemes.classic:
            return LinearGradient(
                colors: [
                    AppTheme.card,
                    AppTheme.cardSoft
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case PortfolioThemes.creative:
            return LinearGradient(
                colors: [
                    Color.purple.opacity(0.20),
                    Color.pink.opacity(0.16),
                    AppTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case PortfolioThemes.olympic:
            return LinearGradient(
                colors: [
                    Color.blue.opacity(0.18),
                    Color.yellow.opacity(0.18),
                    AppTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color.yellow.opacity(0.22),
                    AppTheme.card,
                    AppTheme.primarySoft.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct PortfolioWebEditInfoView: View {
    @Environment(\.dismiss) private var dismiss

    let publicURL: String?
    let publicToken: String?

    private var webURL: URL? {
        URL(string: "https://sc.it-status.ru/")
    }

    private var publicPortfolioURL: URL? {
        if let publicURL,
           let url = URL.schoolFileURL(from: publicURL) {
            return url
        }

        if let publicToken,
           !publicToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(string: "https://sc.it-status.ru/public/portfolio/\(publicToken)")
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 58))
                    .foregroundStyle(AppTheme.control)

                VStack(spacing: 10) {
                    Text("Редактирование через веб-версию")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundStyle(AppTheme.heading)
                        .multilineTextAlignment(.center)

                    Text("В мобильном приложении портфолио открывается в режиме просмотра. Чтобы добавить достижения, бейджи, изображения и файлы, откройте веб-версию школы.")
                        .font(.body)
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    if let webURL {
                        Link(destination: webURL) {
                            Label("Открыть веб-версию", systemImage: "safari.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let publicPortfolioURL {
                        Link(destination: publicPortfolioURL) {
                            Label("Открыть публичное портфолио", systemImage: "link.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("После редактирования в веб-версии обновите этот экран свайпом вниз.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .appScreenBackground()
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PortfolioAvatarView: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL.schoolFileURL(from: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 96, height: 96)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .overlay {
            Circle()
                .stroke(AppTheme.card, lineWidth: 4)
        }
        .shadow(radius: 6)
    }

    private var placeholder: some View {
        Circle()
            .fill(AppTheme.primarySoft)
            .frame(width: 96, height: 96)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.control)
            }
    }
}

private struct PortfolioBlockCard: View {
    let block: PortfolioBlockDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageUrl = block.image_url, let url = URL.schoolFileURL(from: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.card.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            Text(block.title)
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            HStack(spacing: 8) {
                if let category = clean(block.category) {
                    tag(category)
                }

                if let period = clean(block.period_label) {
                    tag(period)
                }

                if let date = clean(block.event_date) {
                    tag(AppDateFormatter.date(date))
                }
            }

            if let description = clean(block.description) {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
            }

            if let level = block.level_value {
                HStack {
                    Text("Уровень")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)

                    ProgressView(value: Double(level), total: 100)
                        .tint(AppTheme.control)

                    Text("\(level)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.heading)
                }
            }

            if let fileUrl = block.file_url,
               let url = URL.schoolFileURL(from: fileUrl) {
                Link(destination: url) {
                    Label(block.file_name ?? "Открыть файл", systemImage: "doc.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: AppTheme.sidebar.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.primarySoft.opacity(0.65))
            .clipShape(Capsule())
    }

    private func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct PortfolioEditView: View {
    @State private var draft: PortfolioDTO

    @State private var isUploading = false
    @State private var uploadError: String?

    @State private var avatarPhotoItem: PhotosPickerItem?
    @State private var blockPhotoItem: PhotosPickerItem?

    @State private var isShowingAvatarPhotoPicker = false
    @State private var isShowingBlockPhotoPicker = false
    @State private var photoTargetBlockId: Int?

    @State private var fileTargetBlockId: Int?
    @State private var isShowingFileImporter = false

    let onUpload: (Data, String, String) async throws -> PortfolioUploadResponseDTO
    let onSave: (PortfolioDTO) -> Void
    let onCancel: () -> Void

    init(
        portfolio: PortfolioDTO,
        onUpload: @escaping (Data, String, String) async throws -> PortfolioUploadResponseDTO,
        onSave: @escaping (PortfolioDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: portfolio)
        self.onUpload = onUpload
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                if isUploading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Загрузка файла...")
                        }
                    }
                }

                if let uploadError {
                    Section {
                        Text(uploadError)
                            .foregroundStyle(.red)
                    }
                }

                Section("Обложка") {
                    TextField("Заголовок", text: optionalTextBinding(\.title))
                    TextField("Слоган", text: optionalTextBinding(\.tagline))

                    TextField("URL аватара", text: optionalTextBinding(\.avatar_url))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    Button {
                        isShowingAvatarPhotoPicker = true
                    } label: {
                        Label("Загрузить аватар из галереи", systemImage: "photo.fill")
                    }

                    VStack(alignment: .leading) {
                        Text("Описание")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: optionalTextBinding(\.summary))
                            .frame(minHeight: 120)
                    }
                }

                Section("Оформление") {
                    Picker("Тема", selection: $draft.theme_code) {
                        ForEach(PortfolioThemes.all, id: \.self) { theme in
                            Text(PortfolioThemes.title(theme))
                                .tag(theme)
                        }
                    }

                    Toggle("Публичная ссылка активна", isOn: $draft.is_public)
                }

                Section("Бейджи") {
                    ForEach($draft.badges) { $badge in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Название бейджа", text: $badge.title)
                            TextField("Описание", text: optionalBadgeTextBinding(badge.id, \.description))
                        }
                    }
                    .onDelete { indexSet in
                        draft.badges.remove(atOffsets: indexSet)
                    }

                    Button {
                        draft.badges.append(.empty(sortOrder: draft.badges.count + 1))
                    } label: {
                        Label("Добавить бейдж", systemImage: "plus")
                    }
                }

                Section("Блоки") {
                    ForEach($draft.blocks) { $block in
                        DisclosureGroup(block.title.isEmpty ? PortfolioBlockTypes.title(block.block_type) : block.title) {
                            Picker("Тип", selection: $block.block_type) {
                                ForEach(PortfolioBlockTypes.all, id: \.self) { type in
                                    Text(PortfolioBlockTypes.title(type))
                                        .tag(type)
                                }
                            }

                            TextField("Заголовок", text: $block.title)
                            TextField("Категория", text: optionalBlockTextBinding(block.id, \.category))
                            TextField("Период", text: optionalBlockTextBinding(block.id, \.period_label))
                            TextField("Дата события YYYY-MM-DD", text: optionalBlockTextBinding(block.id, \.event_date))
                            TextField("Описание", text: optionalBlockTextBinding(block.id, \.description), axis: .vertical)

                            TextField("URL картинки", text: optionalBlockTextBinding(block.id, \.image_url))

                            Button {
                                photoTargetBlockId = block.id
                                isShowingBlockPhotoPicker = true
                            } label: {
                                Label("Загрузить картинку из галереи", systemImage: "photo.fill")
                            }

                            TextField("URL файла", text: optionalBlockTextBinding(block.id, \.file_url))
                            TextField("Имя файла", text: optionalBlockTextBinding(block.id, \.file_name))
                            TextField("Тип файла", text: optionalBlockTextBinding(block.id, \.file_type))

                            Button {
                                fileTargetBlockId = block.id
                                isShowingFileImporter = true
                            } label: {
                                Label("Загрузить документ/файл", systemImage: "doc.badge.plus")
                            }

                            Stepper(
                                "Порядок: \(block.sort_order)",
                                value: $block.sort_order,
                                in: 0...999
                            )

                            Stepper(
                                "Уровень: \(block.level_value ?? 0)",
                                value: optionalIntBinding(block.id, \.level_value),
                                in: 0...100
                            )
                        }
                    }
                    .onDelete { indexSet in
                        draft.blocks.remove(atOffsets: indexSet)
                    }

                    Menu {
                        ForEach(PortfolioBlockTypes.all, id: \.self) { type in
                            Button(PortfolioBlockTypes.title(type)) {
                                draft.blocks.append(.empty(type: type, sortOrder: draft.blocks.count + 1))
                            }
                        }
                    } label: {
                        Label("Добавить блок", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Редактирование")
            .disabled(isUploading)
            .overlay {
                if isUploading {
                    ZStack {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()

                        VStack(spacing: 14) {
                            ProgressView()
                            Text("Загружаем файл...")
                                .font(.headline)
                            Text("Подождите, изображение сжимается и отправляется на сервер.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: 280)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .photosPicker(
                isPresented: $isShowingAvatarPhotoPicker,
                selection: $avatarPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .photosPicker(
                isPresented: $isShowingBlockPhotoPicker,
                selection: $blockPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: avatarPhotoItem) { newItem in
                guard let newItem else {
                    return
                }

                Task {
                    await uploadAvatarPhoto(newItem)
                    avatarPhotoItem = nil
                }
            }
            .onChange(of: blockPhotoItem) { newItem in
                guard let newItem else {
                    return
                }

                Task {
                    await uploadBlockPhoto(newItem)
                    blockPhotoItem = nil
                    photoTargetBlockId = nil
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: allowedFileTypes,
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleImportedFile(result)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                    }
                    .disabled(isUploading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        normalizeSortOrder()
                        onSave(draft)
                    }
                    .disabled(isUploading)
                }
            }
        }
    }

    private var allowedFileTypes: [UTType] {
        var types: [UTType] = [
            .jpeg,
            .png,
            .webP,
            .gif,
            .pdf,
            .zip,
            .data
        ]

        [
            "doc",
            "docx",
            "ppt",
            "pptx",
            "xls",
            "xlsx"
        ].forEach { extensionValue in
            if let type = UTType(filenameExtension: extensionValue) {
                types.append(type)
            }
        }

        return types
    }

    private func uploadAvatarPhoto(_ item: PhotosPickerItem) async {
        do {
            isUploading = true
            uploadError = nil

            let data = try await loadCompressedImageData(from: item)

            let response = try await onUpload(
                data,
                "avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                "image/jpeg"
            )

            draft.avatar_url = response.url
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    private func uploadBlockPhoto(_ item: PhotosPickerItem) async {
        guard let blockId = photoTargetBlockId else {
            return
        }

        do {
            isUploading = true
            uploadError = nil

            let data = try await loadCompressedImageData(from: item)

            let response = try await onUpload(
                data,
                "portfolio-image-\(Int(Date().timeIntervalSince1970)).jpg",
                "image/jpeg"
            )

            guard let index = draft.blocks.firstIndex(where: { $0.id == blockId }) else {
                return
            }

            draft.blocks[index].image_url = response.url
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    private func loadCompressedImageData(from item: PhotosPickerItem) async throws -> Data {
        guard let rawData = try await item.loadTransferable(type: Data.self) else {
            throw APIRequestError.networkError("Не удалось прочитать изображение.")
        }

        return try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: rawData) else {
                if rawData.count <= 25 * 1024 * 1024 {
                    return rawData
                }

                throw APIRequestError.networkError("Файл слишком большой. Максимум 25 МБ.")
            }

            let resized = image.resizedForPortfolio(maxSide: 1800)

            guard let jpegData = resized.jpegData(compressionQuality: 0.78) else {
                throw APIRequestError.networkError("Не удалось подготовить изображение.")
            }

            guard jpegData.count <= 25 * 1024 * 1024 else {
                throw APIRequestError.networkError("Изображение слишком большое после сжатия. Максимум 25 МБ.")
            }

            return jpegData
        }.value
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) async {
        guard let blockId = fileTargetBlockId else {
            return
        }

        do {
            isUploading = true
            uploadError = nil

            let urls = try result.get()
            guard let url = urls.first else {
                return
            }

            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)

            guard data.count <= 25 * 1024 * 1024 else {
                throw APIRequestError.networkError("Файл слишком большой. Максимум 25 МБ.")
            }

            let fileName = url.lastPathComponent
            let mimeType = mimeTypeForURL(url)

            let response = try await onUpload(
                data,
                fileName,
                mimeType
            )

            guard let index = draft.blocks.firstIndex(where: { $0.id == blockId }) else {
                return
            }

            if mimeType.hasPrefix("image/") {
                draft.blocks[index].image_url = response.url
            } else {
                draft.blocks[index].file_url = response.url
                draft.blocks[index].file_name = response.file_name
                draft.blocks[index].file_type = response.file_type
            }
        } catch {
            uploadError = error.localizedDescription
        }

        fileTargetBlockId = nil
        isUploading = false
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "zip":
            return "application/zip"
        default:
            return "application/octet-stream"
        }
    }

    private func optionalTextBinding(_ keyPath: WritableKeyPath<PortfolioDTO, String?>) -> Binding<String> {
        Binding(
            get: {
                draft[keyPath: keyPath] ?? ""
            },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = trimmed.isEmpty ? nil : value
            }
        )
    }

    private func optionalBlockTextBinding(
        _ id: Int,
        _ keyPath: WritableKeyPath<PortfolioBlockDTO, String?>
    ) -> Binding<String> {
        Binding(
            get: {
                draft.blocks.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
            },
            set: { value in
                guard let index = draft.blocks.firstIndex(where: { $0.id == id }) else {
                    return
                }

                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.blocks[index][keyPath: keyPath] = trimmed.isEmpty ? nil : value
            }
        )
    }

    private func optionalBadgeTextBinding(
        _ id: Int,
        _ keyPath: WritableKeyPath<PortfolioBadgeDTO, String?>
    ) -> Binding<String> {
        Binding(
            get: {
                draft.badges.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
            },
            set: { value in
                guard let index = draft.badges.firstIndex(where: { $0.id == id }) else {
                    return
                }

                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.badges[index][keyPath: keyPath] = trimmed.isEmpty ? nil : value
            }
        )
    }

    private func optionalIntBinding(
        _ id: Int,
        _ keyPath: WritableKeyPath<PortfolioBlockDTO, Int?>
    ) -> Binding<Int> {
        Binding(
            get: {
                draft.blocks.first(where: { $0.id == id })?[keyPath: keyPath] ?? 0
            },
            set: { value in
                guard let index = draft.blocks.firstIndex(where: { $0.id == id }) else {
                    return
                }

                draft.blocks[index][keyPath: keyPath] = value
            }
        )
    }

    private func normalizeSortOrder() {
        draft.blocks = draft.blocks
            .enumerated()
            .map { index, block in
                var copy = block
                copy.sort_order = index + 1
                return copy
            }

        draft.badges = draft.badges
            .enumerated()
            .map { index, badge in
                var copy = badge
                copy.sort_order = index + 1
                return copy
            }
    }
}

private extension UIImage {
    func resizedForPortfolio(maxSide: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)

        guard largestSide > maxSide else {
            return self
        }

        let scale = maxSide / largestSide
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private extension View {
    func portfolioCard() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private extension URL {
    static func schoolFileURL(from value: String) -> URL? {
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return URL(string: value)
        }

        if value.hasPrefix("/") {
            return URL(string: "https://sc.it-status.ru\(value)")
        }

        return URL(string: "https://sc.it-status.ru/\(value)")
    }
}