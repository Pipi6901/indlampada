#if os(iOS)
import DeepamCore
import RevenueCatUI
import SwiftUI

/// Управление подпиской: отмена, возврат, смена тарифа, восстановление.
///
/// Apple требует, чтобы из приложения можно было дойти до управления подпиской,
/// и делать это руками — значит написать десяток экранов, которые RevenueCat
/// уже написал.
///
/// Платный экран, в отличие от этого, свой. Готовый `PaywallView` из панели
/// сюда не подставляется: наш показывает ответы человека и подсвечивает по ним
/// набор, а цены и покупку RevenueCat отдаёт и так — через `PaywallStore`.
public struct DeepamCustomerCenter: View {
    public init() {}

    public var body: some View {
        CustomerCenterView()
            // Опрос при отмене настраивается в панели RevenueCat; ответ —
            // идентификатор варианта оттуда же. Сюда приходят те, кто отменяет
            // из приложения; отменивших в настройках iPhone спрашивает свой
            // лист — см. `CancelReasonSheet`.
            .onCustomerCenterFeedbackSurveyCompleted { optionID in
                EventLog.log(.cancelReason(reason: optionID, source: "customer_center",
                                           wasTrial: AppSettings().proStatus?.isTrial ?? false))
            }
    }
}
#endif
