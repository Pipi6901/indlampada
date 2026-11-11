import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Показ на весь экран. На iOS это `fullScreenCover`, на macOS его нет —
    /// там ближайшее по смыслу это обычная шторка. Модуль собирается под обе
    /// платформы, потому что тесты гоняются на маке.
    @ViewBuilder
    func fullCover<C: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }
}

extension DatePicker {
    /// Барабан — на iPhone. На маке его нет, а пакет собирается и там: тесты
    /// гоняются на macOS.
    @ViewBuilder
    func wheelStyle() -> some View {
        #if os(iOS)
        datePickerStyle(.wheel)
        #else
        self
        #endif
    }
}

enum Platform {
    /// Положить строку в буфер обмена. На маке — ничего: там только тесты.
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    /// Настройки уведомлений этого приложения в «Настройках» iPhone.
    static var notificationSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        nil
        #endif
    }
}
