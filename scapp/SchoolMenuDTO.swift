import Foundation

struct MenuFiltersResponseDTO: Codable {
    let classes: [MenuClassFilterDTO]
    let meal_types: [MealTypeDTO]
}

struct MenuClassFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct MealTypeDTO: Codable, Identifiable, Hashable {
    let code: String
    let name: String

    var id: String {
        code
    }
}

struct MenuDishesListResponseDTO: Codable {
    let items: [MenuDishDTO]
}

struct MenuDishDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let calories: Int?
    let allergens: String?
    let price_amount: String?
}

struct MenuDishFormData: Hashable {
    let name: String
    let description: String
    let calories: Int?
    let allergens: String
    let priceAmount: String
}

struct MenuDishCreateRequestDTO: Codable {
    let name: String
    let description: String?
    let calories: Int?
    let allergens: String?
    let price_amount: String?
}

struct MenuDishUpdateRequestDTO: Codable {
    let name: String
    let description: String?
    let calories: Int?
    let allergens: String?
    let price_amount: String?
}

struct MealTimesListResponseDTO: Codable {
    let items: [MealTimeDTO]
}

struct MealTimeDTO: Codable, Identifiable, Hashable {
    let id: Int
    let class_id: Int
    let class_name: String?
    let meal_type: String
    let starts_at: String
    let ends_at: String

    var displayTitle: String {
        "\(starts_at)–\(ends_at)"
    }
}

struct WeeklyMenuResponseDTO: Codable {
    let week_start: String?
    let items: [WeeklyMenuItemDTO]
}

struct WeeklyMenuItemDTO: Codable, Identifiable, Hashable {
    let id: Int
    let menu_date: String
    let meal_type: String
    let class_id: Int?
    let class_name: String?
    let dish_id: Int
    let dish_name: String
    let dish_description: String?
    let calories: Int?
    let allergens: String?
    let price_amount: String?
}

struct WeeklyMenuItemFormData: Hashable {
    let menuDate: String
    let mealType: String
    let dishID: Int
    let classID: Int?
}

struct WeeklyMenuItemCreateRequestDTO: Codable {
    let menu_date: String
    let meal_type: String
    let dish_id: Int
    let class_id: Int?
}

struct WeeklyMenuItemUpdateRequestDTO: Codable {
    let menu_date: String
    let meal_type: String
    let dish_id: Int
    let class_id: Int?
}

struct MenuStatusResponseDTO: Codable {
    let status: String?
    let message: String?
}

struct MenuIDStatusResponseDTO: Codable {
    let id: Int?
    let status: String?
    let message: String?
}