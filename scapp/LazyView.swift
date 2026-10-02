import SwiftUI

/// Создаёт экран-назначение только при переходе. `NavigationLink { X() }` строит `X`
/// сразу, вместе со ссылкой: главная с двумя десятками разделов в отладочной сборке
/// переполняла стек главного потока при запуске (EXC_BAD_ACCESS в ClubsView.init).
struct LazyView<Content: View>: View {
    private let build: () -> Content

    init(_ build: @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}
