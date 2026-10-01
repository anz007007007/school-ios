import Foundation

/// Русские тексты для известных английских `detail` сервера (админка и финансы).
enum APIServerMessageTranslations {
    static let known: [String: String] = [
        "Use dedicated section to create or manage teacher, parent or student users":
            "Роль учителя, родителя или ученика назначается в их разделах админки.",
        "Use dedicated section to create teacher, parent or student users":
            "Учителя, родители и ученики создаются в своих разделах админки.",
        "Only admin can assign admin role": "Назначать роль администратора может только администратор.",
        "Only admin can modify admin users": "Изменять администраторов может только администратор.",
        "Only admin can create admin users": "Создавать администраторов может только администратор.",
        "Only admin or manager can access admin section": "Раздел доступен только администратору и менеджеру.",
        "Only admin or manager can manage finance": "Финансами управляют только администратор и менеджер.",
        "You do not have access to finance data": "Нет доступа к финансовым данным.",
        "You do not have access to finance filters": "Нет доступа к финансовым данным.",
        "You cannot deactivate yourself": "Нельзя отключить свою учётную запись.",
        "User with this login already exists": "Пользователь с таким логином уже существует.",
        "Subject with this name already exists": "Предмет с таким названием уже существует.",
        "Subject is used in grades, homework or schedule": "Предмет используется в оценках, заданиях или расписании.",
        "Term is used in final grades": "Период используется в итоговых оценках.",
        "Class has students. Move students before deleting class.":
            "В классе есть ученики. Сначала переведите их в другой класс.",
        "Invalid billing period format. Expected YYYY-MM": "Неверный расчётный период, нужен формат ГГГГ-ММ.",
        "Some working days are outside selected billing period": "Часть рабочих дней вне выбранного периода.",
        "Some vacation days are outside selected period": "Часть дней отпуска вне выбранного периода.",
        "date_to must be greater than or equal to date_from": "Дата окончания раньше даты начала.",
        "Invoice for this period already exists": "Счёт за этот период уже существует.",
        "Cannot add payment to cancelled invoice": "Нельзя добавить платёж в отменённый счёт.",
        "Student not found": "Ученик не найден.",
        "User not found": "Пользователь не найден.",
        "Class not found": "Класс не найден.",
        "Subject not found": "Предмет не найден.",
        "Teacher not found": "Учитель не найден.",
        "Parent not found": "Родитель не найден.",
        "Term not found": "Учебный период не найден.",
        "Invoice not found": "Счёт не найден.",
        "Payment not found": "Платёж не найден.",
        "Legal entity not found": "Юрлицо не найдено.",
        "Payer INN link not found": "Связь ИНН с учеником не найдена.",
        "Schedule lesson not found": "Урок в расписании не найден.",
        "Uploaded file is empty": "Загруженный файл пустой."
    ]
}
