import SwiftUI
import Combine
import SchoolAPIClient

/// Подразделения школы (корпуса, отделения): GET /api/v1/divisions.
struct DivisionsResponseDTO: Codable {
    let enabled: Bool
    let items: [DivisionDTO]

    enum CodingKeys: String, CodingKey {
        case enabled
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        items = try container.decodeIfPresent([DivisionDTO].self, forKey: .items) ?? []
    }
}

struct DivisionDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let short_name: String?
    let is_active: Bool?
    let sort_order: Int?
    let classes_count: Int?
    let students_count: Int?
    let staff_count: Int?

    var isActive: Bool {
        is_active ?? true
    }

    /// Короткое имя для подписей в списках.
    var displayName: String {
        let short = short_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return short.isEmpty ? name : short
    }
}

/// Общий кэш подразделений. Загружается лениво при открытии форм/экранов,
/// где выбор подразделения может понадобиться.
@MainActor
final class DivisionsStore: ObservableObject {
    static let shared = DivisionsStore()

    @Published private(set) var enabled = false
    @Published private(set) var items: [DivisionDTO] = []
    @Published private(set) var isLoaded = false

    private var loadedToken: String?
    private var loadTask: Task<Void, Never>?

    private init() {}

    var activeDivisions: [DivisionDTO] {
        items
            .filter { $0.isActive }
            .sorted { ($0.sort_order ?? 0, $0.name) < ($1.sort_order ?? 0, $1.name) }
    }

    /// Показывать выбор подразделения имеет смысл, только если функция включена
    /// и активных подразделений больше одного.
    var isUsable: Bool {
        enabled && activeDivisions.count > 1
    }

    func division(id: Int) -> DivisionDTO? {
        items.first { $0.id == id }
    }

    /// Подпись «Для кого» по списку id: пустой список — вся школа.
    func audienceText(_ ids: [Int]?) -> String? {
        guard let ids, !ids.isEmpty else {
            return nil
        }

        let names = ids.compactMap { division(id: $0)?.displayName }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    func load(api: SchoolAPI, force: Bool = false) async {
        let token = api.authToken

        if !force, isLoaded, loadedToken == token {
            return
        }

        if let loadTask {
            await loadTask.value
            if isLoaded, loadedToken == token {
                return
            }
        }

        let task = Task { @MainActor in
            do {
                let response = try await APIRequestService.shared.decode(
                    DivisionsResponseDTO.self,
                    api: api,
                    path: "/api/v1/divisions",
                    logPrefix: "DIVISIONS"
                )
                enabled = response.enabled
                items = response.items
            } catch {
                // Старый сервер без подразделений: просто не показываем выбор.
                enabled = false
                items = []
            }

            isLoaded = true
            loadedToken = token
        }

        loadTask = task
        await task.value
        loadTask = nil
    }
}

/// Выбор «Для кого» в формах контента (только admin/manager).
struct DivisionAudience: Hashable {
    var isWholeSchool: Bool
    var selectedIDs: Set<Int>

    init(divisionIDs: [Int]? = nil) {
        let ids = divisionIDs ?? []
        isWholeSchool = ids.isEmpty
        selectedIDs = Set(ids)
    }

    /// Значение для поля `division_ids`: [] — вся школа, [ids] — только они.
    var divisionIDs: [Int] {
        if isWholeSchool {
            return []
        }

        return selectedIDs.sorted()
    }
}

extension DivisionAudience {
    /// Что отправить на сервер: nil — поле не отправляем (секция не показывалась).
    @MainActor
    func payload(appState: AppState) -> [Int]? {
        guard appState.canChooseDivisionAudience, DivisionsStore.shared.isUsable else {
            return nil
        }

        return divisionIDs
    }
}

extension Dictionary where Key == String, Value == Any {
    /// Добавляет `division_ids` в тело запроса, если значение задано.
    mutating func setDivisionIDs(_ ids: [Int]?) {
        if let ids {
            self["division_ids"] = ids
        }
    }
}

/// Компактная секция формы «Для кого». Ничего не показывает, если пользователь
/// не admin/manager, подразделения выключены или активных меньше двух.
struct DivisionAudienceSection: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var store = DivisionsStore.shared

    @Binding var audience: DivisionAudience

    var body: some View {
        Group {
            if appState.canChooseDivisionAudience && store.isUsable {
                Section {
                    Toggle("Вся школа", isOn: $audience.isWholeSchool)

                    if !audience.isWholeSchool {
                        ForEach(selectableDivisions) { division in
                            Button {
                                toggle(division.id)
                            } label: {
                                HStack {
                                    Text(division.name)
                                        .foregroundStyle(AppTheme.text)

                                    if !division.isActive {
                                        Text("неактивно")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if audience.selectedIDs.contains(division.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.accentDark)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Для кого")
                } footer: {
                    if !audience.isWholeSchool && audience.selectedIDs.isEmpty {
                        Text("Подразделения не выбраны — запись увидит вся школа.")
                    } else if !audience.isWholeSchool {
                        Text("Запись увидят только выбранные подразделения.")
                    }
                }
            }
        }
    }

    /// Активные подразделения плюс уже выбранные неактивные (чтобы их можно было снять).
    private var selectableDivisions: [DivisionDTO] {
        let active = store.activeDivisions
        let activeIDs = Set(active.map(\.id))
        let inactiveSelected = store.items.filter {
            !activeIDs.contains($0.id) && audience.selectedIDs.contains($0.id)
        }
        return active + inactiveSelected
    }

    private func toggle(_ id: Int) {
        if audience.selectedIDs.contains(id) {
            audience.selectedIDs.remove(id)
        } else {
            audience.selectedIDs.insert(id)
        }
    }
}

/// Маленькая подпись с подразделениями для строк списков (только для admin/manager).
struct DivisionAudienceLabel: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var store = DivisionsStore.shared

    let divisionIDs: [Int]?

    var body: some View {
        if appState.canChooseDivisionAudience,
           store.enabled,
           let text = store.audienceText(divisionIDs) {
            Label(text, systemImage: "building.2")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
        }
    }
}

/// Подгружает подразделения для секции «Для кого». Вешается на форму, а не на саму
/// секцию: пока список не загружен, секция пустая и её `.task` не сработал бы.
struct DivisionsAudienceLoader: ViewModifier {
    @EnvironmentObject var appState: AppState

    func body(content: Content) -> some View {
        content.task {
            if appState.canChooseDivisionAudience {
                await DivisionsStore.shared.load(api: appState.api)
            }
        }
    }
}

extension View {
    func loadsDivisionAudience() -> some View {
        modifier(DivisionsAudienceLoader())
    }
}
