import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class SchoolMenuViewModel: ObservableObject {
    @Published var weekItems: [WeeklyMenuItemDTO] = []
    @Published var dishes: [MenuDishDTO] = []
    @Published var classes: [MenuClassFilterDTO] = []
    @Published var mealTypes: [MealTypeDTO] = []
    @Published var mealTimes: [MealTimeDTO] = []

    @Published var selectedWeekStart: Date = Calendar.current.startOfDay(for: Date())
    @Published var selectedDate: String = ""
    @Published var selectedClassID: Int = 0
    @Published var selectedMealType: String = "all"
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    struct MenuDay: Identifiable, Hashable {
        let date: Date
        let dateString: String
        let title: String
        let subtitle: String
        let items: [WeeklyMenuItemDTO]

        var id: String {
            dateString
        }
    }

    struct MenuMealGroup: Identifiable, Hashable {
        let mealType: String
        let title: String
        let items: [WeeklyMenuItemDTO]

        var id: String {
            mealType
        }
    }

    var orderedMealTypes: [MealTypeDTO] {
        mealTypes.sorted {
            if mealTypeOrder($0.code) == mealTypeOrder($1.code) {
                return $0.name < $1.name
            }

            return mealTypeOrder($0.code) < mealTypeOrder($1.code)
        }
    }

    var weekDays: [MenuDay] {
        let start = weekStartDate(selectedWeekStart)

        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let dateString = Self.apiDateFormatter.string(from: date)
            let items = filteredWeekItems.filter { $0.menu_date == dateString }

            return MenuDay(
                date: date,
                dateString: dateString,
                title: dayShortTitle(date),
                subtitle: Self.dayMonthFormatter.string(from: date),
                items: items.sorted {
                    mealTypeOrder($0.meal_type) < mealTypeOrder($1.meal_type)
                }
            )
        }
    }

    var selectedDayItems: [WeeklyMenuItemDTO] {
        guard !selectedDate.isEmpty else {
            return []
        }

        return filteredWeekItems
            .filter { $0.menu_date == selectedDate }
            .sorted {
                if mealTypeOrder($0.meal_type) == mealTypeOrder($1.meal_type) {
                    return $0.dish_name < $1.dish_name
                }

                return mealTypeOrder($0.meal_type) < mealTypeOrder($1.meal_type)
            }
    }

    var selectedDayMealGroups: [MenuMealGroup] {
        let grouped = Dictionary(grouping: selectedDayItems) { $0.meal_type }

        return grouped.map { mealType, items in
            MenuMealGroup(
                mealType: mealType,
                title: mealTypeTitle(mealType),
                items: items.sorted { $0.dish_name < $1.dish_name }
            )
        }
        .sorted {
            mealTypeOrder($0.mealType) < mealTypeOrder($1.mealType)
        }
    }

    var filteredWeekItems: [WeeklyMenuItemDTO] {
        var result = weekItems

        if selectedClassID != 0 {
            result = result.filter { $0.class_id == selectedClassID }
        }

        if selectedMealType != "all" {
            result = result.filter { $0.meal_type == selectedMealType }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.dish_name.localizedCaseInsensitiveContains(query)
                || item.meal_type.localizedCaseInsensitiveContains(query)
                || (item.class_name ?? "").localizedCaseInsensitiveContains(query)
                || (item.dish_description ?? "").localizedCaseInsensitiveContains(query)
                || (item.allergens ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    var filteredDishes: [MenuDishDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return dishes.sorted { $0.name < $1.name }
        }

        return dishes.filter { dish in
            dish.name.localizedCaseInsensitiveContains(query)
            || (dish.description ?? "").localizedCaseInsensitiveContains(query)
            || (dish.allergens ?? "").localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.name < $1.name }
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        selectedWeekStart = weekStartDate(selectedWeekStart)

        if selectedDate.isEmpty {
            selectedDate = Self.apiDateFormatter.string(from: Date())
        }

        async let filtersTask: Void = loadFilters(api: api)
        async let dishesTask: Void = loadDishes(api: api, showLoading: false)
        async let mealTimesTask: Void = loadMealTimes(api: api, showLoading: false)
        async let weekTask: Void = loadWeek(api: api, showLoading: false)

        _ = await (filtersTask, dishesTask, mealTimesTask, weekTask)

        isLoading = false
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/menu/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MenuFiltersResponseDTO.self, from: data)
            classes = decoded.classes
            mealTypes = decoded.meal_types.isEmpty ? defaultMealTypes : decoded.meal_types
            mealTypes = orderedMealTypes
        } catch {
            errorMessage = "Не удалось загрузить фильтры меню: \(error.localizedDescription)"
            mealTypes = defaultMealTypes
        }

        isLoadingFilters = false
    }

    func loadDishes(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/menu/dishes",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MenuDishesListResponseDTO.self, from: data)
            dishes = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить блюда: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadMealTimes(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/menu/meal-times",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MealTimesListResponseDTO.self, from: data)
            mealTimes = decoded.items
        } catch {
            // Не блокируем экран меню, если расписание приёмов пищи не загрузилось.
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadWeek(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            let weekStart = Self.apiDateFormatter.string(from: weekStartDate(selectedWeekStart))

            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "week_start", value: weekStart)
            ]

            if selectedClassID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(selectedClassID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/menu/week",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(WeeklyMenuResponseDTO.self, from: data)
            weekItems = decoded.items

            if selectedDate.isEmpty {
                selectedDate = Self.apiDateFormatter.string(from: weekStartDate(selectedWeekStart))
            }
        } catch {
            errorMessage = "Не удалось загрузить меню недели: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func reload(api: SchoolAPI) async {
        await loadWeek(api: api)
    }

    func goToPreviousWeek(api: SchoolAPI) async {
        selectedWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: selectedWeekStart) ?? selectedWeekStart
        selectedWeekStart = weekStartDate(selectedWeekStart)
        selectedDate = Self.apiDateFormatter.string(from: selectedWeekStart)
        await loadWeek(api: api)
    }

    func goToNextWeek(api: SchoolAPI) async {
        selectedWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
        selectedWeekStart = weekStartDate(selectedWeekStart)
        selectedDate = Self.apiDateFormatter.string(from: selectedWeekStart)
        await loadWeek(api: api)
    }

    func goToCurrentWeek(api: SchoolAPI) async {
        selectedWeekStart = weekStartDate(Date())
        selectedDate = Self.apiDateFormatter.string(from: Date())
        await loadWeek(api: api)
    }

    func createDish(
        api: SchoolAPI,
        formData: MenuDishFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAllergens = formData.allergens.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrice = formData.priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Введите название блюда"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "name": cleanName,
                "description": cleanDescription,
                "calories": formData.calories as Any,
                "allergens": cleanAllergens,
                "price_amount": cleanPrice
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/menu/dishes",
                method: "POST",
                body: body
            )

            successMessage = "Блюдо добавлено"
            await loadDishes(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить блюдо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateDish(
        api: SchoolAPI,
        dishID: Int,
        formData: MenuDishFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAllergens = formData.allergens.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrice = formData.priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Введите название блюда"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "name": cleanName,
                "description": cleanDescription,
                "calories": formData.calories as Any,
                "allergens": cleanAllergens,
                "price_amount": cleanPrice
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/menu/dishes/\(dishID)",
                method: "PUT",
                body: body
            )

            successMessage = "Блюдо обновлено"
            await loadDishes(api: api, showLoading: false)
            await loadWeek(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить блюдо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createWeeklyMenuItem(
        api: SchoolAPI,
        formData: WeeklyMenuItemFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.dishID != 0 else {
            errorMessage = "Выберите блюдо"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "menu_date": formData.menuDate,
                "meal_type": formData.mealType,
                "dish_id": formData.dishID,
                "class_id": formData.classID as Any
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/menu/week",
                method: "POST",
                body: body
            )

            successMessage = "Блюдо добавлено в меню"
            await loadWeek(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить блюдо в меню: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateWeeklyMenuItem(
        api: SchoolAPI,
        itemID: Int,
        formData: WeeklyMenuItemFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.dishID != 0 else {
            errorMessage = "Выберите блюдо"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "menu_date": formData.menuDate,
                "meal_type": formData.mealType,
                "dish_id": formData.dishID,
                "class_id": formData.classID as Any
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/menu/week/\(itemID)",
                method: "PUT",
                body: body
            )

            successMessage = "Пункт меню обновлён"
            await loadWeek(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить пункт меню: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteWeeklyMenuItem(
        api: SchoolAPI,
        item: WeeklyMenuItemDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/menu/week/\(item.id)",
                method: "DELETE"
            )

            weekItems.removeAll { $0.id == item.id }
            successMessage = "Пункт меню удалён"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить пункт меню: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func mealTypeTitle(_ value: String) -> String {
        if let found = mealTypes.first(where: { $0.code == value }) {
            return found.name
        }

        switch value {
        case "breakfast":
            return "Завтрак"
        case "second_breakfast", "secondBreakfast", "second-breakfast", "brunch":
            return "Второй завтрак"
        case "lunch":
            return "Обед"
        case "snack", "afternoon_snack", "afternoonSnack", "afternoon-snack":
            return "Полдник"
        case "dinner":
            return "Ужин"
        default:
            return value
        }
    }

    func mealTypeOrder(_ value: String) -> Int {
        switch value {
        case "breakfast":
            return 1
        case "second_breakfast", "secondBreakfast", "second-breakfast", "brunch":
            return 2
        case "lunch":
            return 3
        case "snack", "afternoon_snack", "afternoonSnack", "afternoon-snack":
            return 4
        case "dinner":
            return 5
        default:
            return 99
        }
    }

    func dayTitle(_ dateString: String) -> String {
        guard let date = Self.apiDateFormatter.date(from: dateString) else {
            return dateString
        }

        if Calendar.current.isDateInToday(date) {
            return "Сегодня, \(Self.fullDateFormatter.string(from: date))"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Завтра, \(Self.fullDateFormatter.string(from: date))"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера, \(Self.fullDateFormatter.string(from: date))"
        }

        return Self.fullDateFormatter.string(from: date)
    }

    func weekRangeTitle() -> String {
        let start = weekStartDate(selectedWeekStart)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start

        return "\(Self.dayMonthFormatter.string(from: start)) — \(Self.dayMonthFormatter.string(from: end))"
    }

    func dishByID(_ id: Int) -> MenuDishDTO? {
        dishes.first { $0.id == id }
    }

    private func dayShortTitle(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }

    private func weekStartDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7

        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw SchoolMenuError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SchoolMenuError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("MENU REQUEST:", method, url.absoluteString)
            print("MENU BODY:", body)
        } else {
            print("MENU REQUEST:", method, url.absoluteString)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SchoolMenuError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("MENU RESPONSE STATUS:", httpResponse.statusCode)
        print("MENU RESPONSE BODY:", responseText)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw SchoolMenuError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SchoolMenuError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private var defaultMealTypes: [MealTypeDTO] {
        [
            MealTypeDTO(code: "breakfast", name: "Завтрак"),
            MealTypeDTO(code: "second_breakfast", name: "Второй завтрак"),
            MealTypeDTO(code: "lunch", name: "Обед"),
            MealTypeDTO(code: "snack", name: "Полдник"),
            MealTypeDTO(code: "dinner", name: "Ужин")
        ]
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

enum SchoolMenuError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}