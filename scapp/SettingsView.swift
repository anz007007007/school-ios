import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Приложение") {
                    LabeledContent("Версия", value: "1.0")
                    LabeledContent("Сервер", value: "83.217.13.81")
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
