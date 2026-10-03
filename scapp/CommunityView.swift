import SwiftUI
import UniformTypeIdentifiers

private struct CommunityParentAdRoute: Identifiable {
    let id = UUID()
    let ad: CommunityParentAdDTO
}

struct CommunityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CommunityViewModel()

    @State private var parentAdRoute: CommunityParentAdRoute?
    @State private var selectedNeed: CommunitySchoolNeedDTO?

    @State private var isShowingMyParentAdForm = false
    @State private var isShowingAdminPromoCreateForm = false
    @State private var selectedAdminPromo: CommunityAdminPromoDTO?

    @State private var isShowingAdminNeedCreateForm = false
    @State private var selectedAdminNeed: CommunitySchoolNeedDTO?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                managementSection

                if viewModel.isLoading {
                    ProgressView("Загружаем раздел...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }

                if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                }

                if let successMessage = viewModel.successMessage {
                    successView(successMessage)
                }

                parentAdsSection
                    .zIndex(100)

                schoolNeedsSection
                    .zIndex(0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Объявления")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCommunityData()
        }
        .refreshable {
            await loadCommunityData()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await loadCommunityData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .fullScreenCover(item: $parentAdRoute) { route in
            CommunityParentAdModalView(ad: route.ad)
        }
        .sheet(item: $selectedNeed) { need in
            CommunityNeedContributionView(
                need: need,
                isSending: viewModel.isSendingContribution
            ) { amount, comment in
                Task {
                    await viewModel.sendContribution(
                        api: appState.api,
                        needID: need.id,
                        amount: amount,
                        comment: comment
                    )
                    selectedNeed = nil
                }
            }
        }
        .sheet(isPresented: $isShowingMyParentAdForm) {
            CommunityParentAdFormView(
                initialAd: viewModel.myParentAd,
                isSaving: viewModel.isSaving
            ) { formData in
                Task {
                    let success = await viewModel.saveMyParentAd(
                        api: appState.api,
                        formData: formData
                    )

                    if success {
                        isShowingMyParentAdForm = false
                    }
                }
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingAdminPromoCreateForm) {
            CommunityPromoFormView(
                promo: nil,
                isSaving: viewModel.isSaving
            ) { formData in
                Task {
                    let success = await viewModel.createAdminPromo(
                        api: appState.api,
                        formData: formData
                    )

                    if success {
                        isShowingAdminPromoCreateForm = false
                    }
                }
            } onDelete: {
                nil
            }
            .environmentObject(appState)
        }
        .sheet(item: $selectedAdminPromo) { promo in
            CommunityPromoFormView(
                promo: promo,
                isSaving: viewModel.isSaving
            ) { formData in
                Task {
                    let success = await viewModel.updateAdminPromo(
                        api: appState.api,
                        promoID: promo.id,
                        formData: formData
                    )

                    if success {
                        selectedAdminPromo = nil
                    }
                }
            } onDelete: {
                Task {
                    let success = await viewModel.deleteAdminPromo(
                        api: appState.api,
                        promoID: promo.id
                    )

                    if success {
                        selectedAdminPromo = nil
                    }
                }

                return nil
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingAdminNeedCreateForm) {
            CommunityNeedFormView(
                need: nil,
                isSaving: viewModel.isSaving
            ) { formData in
                Task {
                    let success = await viewModel.createAdminNeed(
                        api: appState.api,
                        formData: formData
                    )

                    if success {
                        isShowingAdminNeedCreateForm = false
                    }
                }
            } onDelete: {
                nil
            }
            .environmentObject(appState)
        }
        .sheet(item: $selectedAdminNeed) { need in
            CommunityNeedFormView(
                need: need,
                isSaving: viewModel.isSaving
            ) { formData in
                Task {
                    let success = await viewModel.updateAdminNeed(
                        api: appState.api,
                        needID: need.id,
                        formData: formData
                    )

                    if success {
                        selectedAdminNeed = nil
                    }
                }
            } onDelete: {
                Task {
                    let success = await viewModel.deleteAdminNeed(
                        api: appState.api,
                        needID: need.id
                    )

                    if success {
                        selectedAdminNeed = nil
                    }
                }

                return nil
            }
            .environmentObject(appState)
        }
    }

    private func loadCommunityData() async {
        async let dashboardTask: Void = viewModel.loadDashboard(api: appState.api)
        async let parentAdTask: Void = loadMyParentAdIfNeeded()
        async let adminPromosTask: Void = loadAdminPromosIfNeeded()

        _ = await (dashboardTask, parentAdTask, adminPromosTask)
    }

    private func loadMyParentAdIfNeeded() async {
        if appState.isParent {
            await viewModel.loadMyParentAd(api: appState.api)
        }
    }

    private func loadAdminPromosIfNeeded() async {
        if appState.isAdmin || appState.isManager {
            await viewModel.loadAdminPromos(api: appState.api)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Объявления и потребности", systemImage: "megaphone.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.sidebar)

            Text("Предложения родителей и актуальные потребности школы.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.sidebar.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.isParent {
                Button {
                    isShowingMyParentAdForm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(AppTheme.sidebar)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.myParentAd == nil ? "Создать своё объявление" : "Редактировать своё объявление")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            Text("Родитель может иметь одно активное или скрытое объявление.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding()
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if appState.isAdmin || appState.isManager {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Промо школы")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Spacer()

                        Button {
                            isShowingAdminPromoCreateForm = true
                        } label: {
                            Label("Создать", systemImage: "plus")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }

                    if viewModel.adminPromos.isEmpty {
                        Text("Промо пока не созданы или не загружены.")
                            .font(.footnote)
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
                        ForEach(viewModel.adminPromos) { promo in
                            Button {
                                selectedAdminPromo = promo
                            } label: {
                                CommunityAdminPromoRowView(promo: promo)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Управление потребностями")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Spacer()

                        Button {
                            isShowingAdminNeedCreateForm = true
                        } label: {
                            Label("Создать", systemImage: "plus")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }

                    Text("Для редактирования существующей потребности нажмите на её карточку ниже.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card.opacity(0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var parentAdsSection: some View {
        let cardWidth = UIScreen.main.bounds.width - 32

        return VStack(alignment: .leading, spacing: 12) {
            Text("Предложения родителей")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if viewModel.parentAds.isEmpty && !viewModel.isLoading {
                emptyBlock(
                    title: "Пока нет предложений",
                    subtitle: "Когда родители добавят объявления, они появятся здесь.",
                    icon: "person.2.slash.fill"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.parentAds) { ad in
                        CommunityParentAdFixedButtonCard(
                            ad: ad,
                            width: cardWidth
                        ) {
                            print("PARENT AD CARD TAP:", ad.id, ad.title)
                            parentAdRoute = CommunityParentAdRoute(ad: ad)
                        }
                    }
                }
                .frame(width: cardWidth, alignment: .leading)
            }
        }
        .frame(width: cardWidth, alignment: .leading)
        .zIndex(100)
    }

    private var schoolNeedsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Потребности школы")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if viewModel.schoolNeeds.isEmpty && !viewModel.isLoading {
                emptyBlock(
                    title: "Потребностей пока нет",
                    subtitle: "Актуальные сборы и запросы школы появятся здесь.",
                    icon: "heart.circle.fill"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.schoolNeeds) { need in
                        CommunityNeedCardView(need: need) {
                            if appState.isAdmin || appState.isManager {
                                selectedAdminNeed = need
                            } else {
                                selectedNeed = need
                            }
                        }
                    }
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            Button("Повторить") {
                Task {
                    await viewModel.loadDashboard(api: appState.api)
                }
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func successView(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.success.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func emptyBlock(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.muted)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct CommunityParentAdThumbnailView: View {
    let ad: CommunityParentAdDTO

    var body: some View {
        Group {
            if let url = ad.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 72, height: 72)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

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
        .frame(width: 72, height: 72)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(width: 72, height: 72)

            Image(systemName: "photo.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.sidebar)
        }
        .frame(width: 72, height: 72)
    }
}

struct CommunityParentAdFixedButtonCard: View {
    let ad: CommunityParentAdDTO
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Button {
                onTap()
            } label: {
                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .frame(width: width, height: 112)
            }
            .buttonStyle(.plain)
            .frame(width: width, height: 112)

            HStack(spacing: 14) {
                CommunityParentAdThumbnailView(ad: ad)

                VStack(alignment: .leading, spacing: 5) {
                    Text(ad.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(ad.short_description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Label(ad.parent_name, systemImage: "person.crop.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.sidebar)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.sidebar)

                    Text("Открыть")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.sidebar)
                }
                .frame(width: 64)
            }
            .padding()
            .frame(width: width, height: 112)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: 112)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.card.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .shadow(color: AppTheme.sidebar.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

struct CommunityParentAdModalView: View {
    let ad: CommunityParentAdDTO
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    imageView

                    VStack(alignment: .leading, spacing: 10) {
                        Text(ad.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.text)

                        Label(ad.parent_name, systemImage: "person.crop.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.sidebar)

                        Text(ad.description)
                            .font(.body)
                            .foregroundStyle(AppTheme.text)

                        if let contact = ad.contact_text?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !contact.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Контакты")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)

                                Text(contact)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Предложение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = ad.fullImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)

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

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 220)

            Image(systemName: "photo.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
        .padding(.horizontal)
    }
}

struct CommunityNeedCardView: View {
    let need: CommunitySchoolNeedDTO
    let onContribute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            imageView

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(need.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Label(need.typeTitle, systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.sidebar)
                    }

                    Spacer()

                    if let count = need.contributions_count {
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AppTheme.primarySoft.opacity(0.8))
                            .foregroundStyle(AppTheme.sidebar)
                            .clipShape(Capsule())
                    }
                }

                Text(need.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                if let goal = need.goal_text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !goal.isEmpty {
                    Label(goal, systemImage: "target")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.text)
                }

                if need.goal_amount != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: need.progressValue ?? 0)
                            .tint(AppTheme.success)

                        HStack {
                            Text(need.collectedText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)

                            Spacer()

                            if let percent = need.progress_percent {
                                Text("\(Int(percent.rounded()))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                Button {
                    onContribute()
                } label: {
                    Label("Я помог / хочу помочь", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.sidebar.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = need.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()

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

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 150)

            Image(systemName: "heart.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
    }
}

struct CommunityNeedContributionView: View {
    let need: CommunitySchoolNeedDTO
    let isSending: Bool
    let onSubmit: (_ amount: Double?, _ comment: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(need.title)
                        .font(.headline)

                    Text(need.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Ваш вклад") {
                    if need.need_type == "money" {
                        TextField("Сумма, например 500", text: $amountText)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Комментарий", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        onSubmit(parsedAmount, cleanComment)
                    } label: {
                        HStack {
                            Spacer()

                            if isSending {
                                ProgressView()
                            } else {
                                Text("Отправить")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSending)
                }
            }
            .navigationTitle("Помощь школе")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedAmount: Double? {
        let normalized = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalized.isEmpty else {
            return nil
        }

        return Double(normalized)
    }

    private var cleanComment: String? {
        let value = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct CommunityPromoModalView: View {
    let promo: CommunityPromoDTO
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    imageView

                    VStack(alignment: .leading, spacing: 12) {
                        Text(promo.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.text)

                        Text(promo.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.text)

                        Text(promo.impressionText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.primarySoft.opacity(0.8))
                            .foregroundStyle(AppTheme.sidebar)
                            .clipShape(Capsule())

                        Button {
                            onClose()
                        } label: {
                            Text("Закрыть")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Объявление")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        onClose()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = promo.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)

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

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 220)

            Image(systemName: "megaphone.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
        .padding(.horizontal)
    }
}

struct CommunityAdminPromoRowView: View {
    let promo: CommunityAdminPromoDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(promo.status == "published" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: promo.status == "published" ? "megaphone.fill" : "megaphone")
                    .foregroundStyle(promo.status == "published" ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(promo.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)

                Text(promo.targetRolesText.isEmpty ? "Аудитория не указана" : promo.targetRolesText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)

                Text("Статус: \(CommunityPromoStatus.title(promo.status)), лимит показов: \(promo.impressions_limit)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.sidebar)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct CommunityParentAdFormView: View {
    @EnvironmentObject var appState: AppState

    let initialAd: CommunityParentAdDTO?
    let isSaving: Bool
    let onSave: (CommunityParentAdFormData) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var formData: CommunityParentAdFormData
    @State private var validationMessage: String?
    @State private var uploadError: String?
    @State private var isUploading = false

    @State private var isShowingIconPhotoPicker = false
    @State private var isShowingFullPhotoPicker = false
    @State private var isShowingIconFilePicker = false
    @State private var isShowingFullFilePicker = false

    init(
        initialAd: CommunityParentAdDTO?,
        isSaving: Bool,
        onSave: @escaping (CommunityParentAdFormData) -> Void
    ) {
        self.initialAd = initialAd
        self.isSaving = isSaving
        self.onSave = onSave
        _formData = State(initialValue: CommunityParentAdFormData(ad: initialAd))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isUploading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Загружаем изображение...")
                        }
                    }
                }

                if let uploadError {
                    Section {
                        Label("Ошибка загрузки", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)

                        Text(uploadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Основное") {
                    TextField("Заголовок", text: $formData.title)

                    TextField("Краткое описание для плитки", text: $formData.shortDescription, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Полное описание", text: $formData.description, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Иконка для плитки") {
                    imagePreview(urlString: formData.iconURL, fallbackSystemImage: "photo.fill")

                    Button {
                        isShowingIconPhotoPicker = true
                    } label: {
                        Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        isShowingIconFilePicker = true
                    } label: {
                        Label("Выбрать из файлов", systemImage: "folder")
                    }
                    .disabled(isUploading)

                    if !formData.iconURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(role: .destructive) {
                            formData.iconURL = ""
                        } label: {
                            Label("Удалить иконку", systemImage: "trash")
                        }
                        .disabled(isUploading)
                    }
                }

                Section("Большая картинка") {
                    imagePreview(urlString: formData.imageURL, fallbackSystemImage: "photo.fill")

                    Button {
                        isShowingFullPhotoPicker = true
                    } label: {
                        Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        isShowingFullFilePicker = true
                    } label: {
                        Label("Выбрать из файлов", systemImage: "folder")
                    }
                    .disabled(isUploading)

                    if !formData.imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(role: .destructive) {
                            formData.imageURL = ""
                        } label: {
                            Label("Удалить картинку", systemImage: "trash")
                        }
                        .disabled(isUploading)
                    }
                }

                Section("Контакты и статус") {
                    TextField("Контакты", text: $formData.contactText, axis: .vertical)
                        .lineLimit(2...5)

                    Picker("Статус", selection: $formData.status) {
                        Text("Активно").tag("active")
                        Text("Скрыто").tag("hidden")
                    }
                    .pickerStyle(.segmented)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving || isUploading)
                }
            }
            .navigationTitle(initialAd == nil ? "Новое объявление" : "Моё объявление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(isSaving || isUploading)
                }
            }
            .sheet(isPresented: $isShowingIconPhotoPicker) {
                CommunityPhotoPickerView { result in
                    Task {
                        await handlePickedImage(result, target: .icon)
                    }
                }
            }
            .sheet(isPresented: $isShowingFullPhotoPicker) {
                CommunityPhotoPickerView { result in
                    Task {
                        await handlePickedImage(result, target: .full)
                    }
                }
            }
            .sheet(isPresented: $isShowingIconFilePicker) {
                CommunityDocumentImagePickerView { result in
                    Task {
                        await handlePickedImage(result, target: .icon)
                    }
                }
            }
            .sheet(isPresented: $isShowingFullFilePicker) {
                CommunityDocumentImagePickerView { result in
                    Task {
                        await handlePickedImage(result, target: .full)
                    }
                }
            }
        }
    }

    private enum ImageTarget {
        case icon
        case full
    }

    private func save() {
        validationMessage = nil

        guard formData.isValid else {
            validationMessage = "Заполните заголовок, краткое и полное описание."
            return
        }

        onSave(formData)
    }

    private func handlePickedImage(
        _ result: Result<CommunityPickedImage, Error>,
        target: ImageTarget
    ) async {
        isUploading = true
        uploadError = nil

        do {
            let picked = try result.get()

            print("COMMUNITY FORM PICKED IMAGE FILE SIZE:", picked.fileSize)

            guard picked.fileSize > 0 else {
                throw CommunityImageError.message("Файл пустой.")
            }

            guard picked.fileSize <= 25 * 1024 * 1024 else {
                throw CommunityImageError.message("Файл слишком большой (больше 25 МБ). Выберите изображение поменьше: после сжатия оно должно быть не больше 8 МБ.")
            }

            let url = try await CommunityImageUploadService.uploadPickedImage(
                api: appState.api,
                picked: picked
            )

            applyUploadedURL(url, target: target)
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    private func applyUploadedURL(_ url: String, target: ImageTarget) {
        switch target {
        case .icon:
            formData.iconURL = url
        case .full:
            formData.imageURL = url
        }
    }

    private func imagePreview(urlString: String, fallbackSystemImage: String) -> some View {
        Group {
            if let url = CommunityConstants.resolveImageUrl(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                    case .failure:
                        placeholder(fallbackSystemImage)

                    @unknown default:
                        placeholder(fallbackSystemImage)
                    }
                }
            } else {
                placeholder(fallbackSystemImage)
            }
        }
    }

    private func placeholder(_ systemImage: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 110)

            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
    }
}

struct CommunityPromoFormView: View {
    @EnvironmentObject var appState: AppState

    let promo: CommunityAdminPromoDTO?
    let isSaving: Bool
    let onSave: (CommunityPromoFormData) -> Void
    let onDelete: () -> Void?

    @Environment(\.dismiss) private var dismiss
    @State private var formData: CommunityPromoFormData
    @State private var validationMessage: String?
    @State private var uploadError: String?
    @State private var isUploading = false
    @State private var showDeleteAlert = false

    @State private var isShowingPhotoPicker = false
    @State private var isShowingFilePicker = false

    init(
        promo: CommunityAdminPromoDTO?,
        isSaving: Bool,
        onSave: @escaping (CommunityPromoFormData) -> Void,
        onDelete: @escaping () -> Void?
    ) {
        self.promo = promo
        self.isSaving = isSaving
        self.onSave = onSave
        self.onDelete = onDelete
        _formData = State(initialValue: CommunityPromoFormData(promo: promo))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isUploading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Загружаем изображение...")
                        }
                    }
                }

                if let uploadError {
                    Section {
                        Label("Ошибка загрузки", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)

                        Text(uploadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Промо") {
                    TextField("Заголовок", text: $formData.title)

                    TextField("Текст объявления", text: $formData.body, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Картинка") {
                    imagePreview

                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        isShowingFilePicker = true
                    } label: {
                        Label("Выбрать из файлов", systemImage: "folder")
                    }
                    .disabled(isUploading)

                    if !formData.imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(role: .destructive) {
                            formData.imageURL = ""
                        } label: {
                            Label("Удалить картинку", systemImage: "trash")
                        }
                        .disabled(isUploading)
                    }
                }

                Section("Аудитория") {
                    ForEach(CommunityRole.promoTargetRoles, id: \.self) { role in
                        Toggle(
                            CommunityRole.title(role),
                            isOn: roleBinding(role)
                        )
                    }
                }

                Section("Показы") {
                    Stepper(
                        "Лимит показов: \(formData.impressionsLimit)",
                        value: $formData.impressionsLimit,
                        in: 1...20
                    )

                    TextField("Дата начала или пусто", text: $formData.startsAt)
                    TextField("Дата окончания или пусто", text: $formData.endsAt)

                    Text("Даты можно оставить пустыми. Если заполняете, укажите дату и время в формате 2026-07-18T12:00:00.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Статус") {
                    Picker("Статус", selection: $formData.status) {
                        Text("Черновик").tag("draft")
                        Text("Опубликовано").tag("published")
                        Text("Архив").tag("archived")
                    }
                    .pickerStyle(.segmented)
                }

                DivisionAudienceSection(audience: $formData.divisionAudience)

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving || isUploading)
                }

                if promo != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить промо", systemImage: "trash.fill")
                        }
                        .disabled(isSaving || isUploading)
                    }
                }
            }
            .loadsDivisionAudience()
            .navigationTitle(promo == nil ? "Новое промо" : "Редактирование промо")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(isSaving || isUploading)
                }
            }
            .sheet(isPresented: $isShowingPhotoPicker) {
                CommunityPhotoPickerView { result in
                    Task {
                        await handlePickedImage(result)
                    }
                }
            }
            .sheet(isPresented: $isShowingFilePicker) {
                CommunityDocumentImagePickerView { result in
                    Task {
                        await handlePickedImage(result)
                    }
                }
            }
            .alert("Удалить промо?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    _ = onDelete()
                }
            } message: {
                Text("Промо будет удалено. Это действие нельзя отменить.")
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let url = CommunityConstants.resolveImageUrl(formData.imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

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
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 130)

            Image(systemName: "megaphone.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
    }

    private func roleBinding(_ role: String) -> Binding<Bool> {
        Binding(
            get: {
                formData.targetRoles.contains(role)
            },
            set: { value in
                if value {
                    formData.targetRoles.insert(role)
                } else {
                    formData.targetRoles.remove(role)
                }
            }
        )
    }

    private func save() {
        validationMessage = nil

        guard formData.isValid else {
            validationMessage = "Заполните заголовок, текст, аудиторию и лимит показов."
            return
        }

        var formData = formData
        formData.divisionIDs = formData.divisionAudience.payload(appState: appState)
        onSave(formData)
    }

    private func handlePickedImage(_ result: Result<CommunityPickedImage, Error>) async {
        isUploading = true
        uploadError = nil

        do {
            let picked = try result.get()

            print("COMMUNITY PROMO FORM PICKED IMAGE FILE SIZE:", picked.fileSize)

            guard picked.fileSize > 0 else {
                throw CommunityImageError.message("Файл пустой.")
            }

            guard picked.fileSize <= 25 * 1024 * 1024 else {
                throw CommunityImageError.message("Файл слишком большой (больше 25 МБ). Выберите изображение поменьше: после сжатия оно должно быть не больше 8 МБ.")
            }

            let url = try await CommunityImageUploadService.uploadPickedImage(
                api: appState.api,
                picked: picked
            )

            formData.imageURL = url
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }
}

struct CommunityNeedFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let need: CommunitySchoolNeedDTO?
    let isSaving: Bool
    let onSave: (CommunityNeedFormData) -> Void
    let onDelete: () -> Void?

    @State private var formData: CommunityNeedFormData
    @State private var validationMessage: String?
    @State private var uploadError: String?
    @State private var isUploading = false
    @State private var showDeleteAlert = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFilePicker = false

    init(
        need: CommunitySchoolNeedDTO?,
        isSaving: Bool,
        onSave: @escaping (CommunityNeedFormData) -> Void,
        onDelete: @escaping () -> Void?
    ) {
        self.need = need
        self.isSaving = isSaving
        self.onSave = onSave
        self.onDelete = onDelete
        _formData = State(initialValue: CommunityNeedFormData(need: need))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isUploading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Загружаем изображение...")
                        }
                    }
                }

                if let uploadError {
                    Section {
                        Label("Ошибка загрузки", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)

                        Text(uploadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Основное") {
                    TextField("Название потребности", text: $formData.title)

                    TextField("Описание", text: $formData.description, axis: .vertical)
                        .lineLimit(4...8)

                    Picker("Тип помощи", selection: $formData.needType) {
                        ForEach(CommunityNeedTypes.all, id: \.self) { type in
                            Text(CommunityNeedTypes.title(type)).tag(type)
                        }
                    }
                }

                Section("Картинка") {
                    imagePreview

                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        isShowingFilePicker = true
                    } label: {
                        Label("Выбрать из файлов", systemImage: "folder")
                    }
                    .disabled(isUploading)

                    if !formData.imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(role: .destructive) {
                            formData.imageURL = ""
                        } label: {
                            Label("Удалить картинку", systemImage: "trash")
                        }
                        .disabled(isUploading)
                    }
                }

                Section("Цель и прогресс") {
                    if formData.needType == CommunityNeedTypes.money {
                        TextField("Цель в рублях, например 10000", text: $formData.goalAmount)
                            .keyboardType(.decimalPad)

                        TextField("Собрано, например 2500", text: $formData.collectedAmount)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Текст цели, например 20 пачек бумаги А4", text: $formData.goalText, axis: .vertical)
                        .lineLimit(2...4)

                    Stepper("Приоритет: \(formData.priority)", value: $formData.priority, in: 0...999)
                }

                Section("Статус") {
                    Picker("Статус", selection: $formData.status) {
                        Text("Активно").tag("active")
                        Text("Выполнено").tag("completed")
                        Text("Архив").tag("archived")
                    }
                    .pickerStyle(.segmented)
                }

                DivisionAudienceSection(audience: $formData.divisionAudience)

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving || isUploading)
                }

                if need != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить потребность", systemImage: "trash.fill")
                        }
                        .disabled(isSaving || isUploading)
                    }
                }
            }
            .loadsDivisionAudience()
            .navigationTitle(need == nil ? "Новая потребность" : "Потребность школы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(isSaving || isUploading)
                }
            }
            .sheet(isPresented: $isShowingPhotoPicker) {
                CommunityPhotoPickerView { result in
                    Task {
                        await handlePickedImage(result)
                    }
                }
            }
            .sheet(isPresented: $isShowingFilePicker) {
                CommunityDocumentImagePickerView { result in
                    Task {
                        await handlePickedImage(result)
                    }
                }
            }
            .alert("Удалить потребность?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    _ = onDelete()
                }
            } message: {
                Text("Потребность будет удалена. Это действие нельзя отменить.")
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let url = CommunityConstants.resolveImageUrl(formData.imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

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
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.primarySoft.opacity(0.8))
                .frame(height: 130)

            Image(systemName: "heart.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.sidebar)
        }
    }

    private func save() {
        validationMessage = nil

        guard formData.isValid else {
            validationMessage = "Заполните название, описание и тип помощи."
            return
        }

        var formData = formData
        formData.divisionIDs = formData.divisionAudience.payload(appState: appState)
        onSave(formData)
    }

    private func handlePickedImage(_ result: Result<CommunityPickedImage, Error>) async {
        isUploading = true
        uploadError = nil

        do {
            let picked = try result.get()

            print("COMMUNITY NEED FORM PICKED IMAGE FILE SIZE:", picked.fileSize)

            guard picked.fileSize > 0 else {
                throw CommunityImageError.message("Файл пустой.")
            }

            guard picked.fileSize <= 25 * 1024 * 1024 else {
                throw CommunityImageError.message("Файл слишком большой (больше 25 МБ). Выберите изображение поменьше: после сжатия оно должно быть не больше 8 МБ.")
            }

            let url = try await CommunityImageUploadService.uploadPickedImage(
                api: appState.api,
                picked: picked
            )

            formData.imageURL = url
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }
}