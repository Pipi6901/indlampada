import DeepamCore
import SwiftUI

/// Время стиха дня: в настройках — минуты от полуночи, в интерфейсе — дата
/// для `DatePicker` и строка вроде «8:00» или «8:00 AM».
enum ClockTime {
    static func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    static func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
    }

    /// По языку приложения, а не устройства: в английском интерфейсе на
    /// русском телефоне «8:00 AM», как и всё остальное вокруг.
    static func text(minutes: Int, locale: AppLocale) -> String {
        date(minutes: minutes).formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: locale.rawValue)))
    }
}

extension AppSettings {
    /// Включает стих дня, спросив систему. Отказала — флаг остаётся выключенным:
    /// включённый без разрешения он обещал бы уведомления, которых не будет.
    ///
    /// Системный вопрос показывается один раз в жизни приложения; дальше ответ
    /// приходит сразу, и тогда исправить его можно только в настройках iPhone.
    @discardableResult
    func turnOnDailyVerse(source: String) async -> Bool {
        let granted = await Reminders.requestPermission()
        EventLog.log(.pushPermission(granted: granted, source: source))
        dailyVerseEnabled = granted
        return granted
    }
}

/// Строка «Стих дня в уведомлении» в разделе «В моменте».
///
/// Стоит рядом с паузой перед лентой не случайно: это тоже место, где стих
/// встречает человека сам, без приложения. Бесплатно — как и всё, что
/// возвращает человека к стиху.
struct DailyVerseRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings

    @State private var showsSheet = false

    var body: some View {
        Button { showsSheet = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(theme.chrome)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "bell")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.chromeInk)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n[.dailyVerseTitle])
                        .font(theme.ui(14, weight: 500))
                        .foregroundStyle(settings.dailyVerseEnabled ? theme.text : theme.textMuted)
                    Text(status)
                        .font(theme.ui(11))
                        .foregroundStyle(theme.textFaint)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.raised)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsSheet) { DailyVerseSheet(settings: settings) }
    }

    private var status: String {
        settings.dailyVerseEnabled
            ? l10n(.dailyVerseOn, ClockTime.text(minutes: settings.dailyVerseMinutes, locale: l10n.locale))
            : l10n[.dailyVerseOff]
    }
}

/// «Новости и обновления» в разделе «В моменте» — согласие на рекламные
/// рассылки по правилу 4.5.4. Здесь же от них и отписываются: правило требует,
/// чтобы это можно было сделать в самом приложении.
///
/// Включение тем, кого про уведомления ещё не спрашивали, сначала задаёт
/// системный вопрос: без разрешения согласие ничего бы не давало.
struct PromoRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.chrome)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "megaphone")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.chromeInk)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n[.promoTitle])
                    .font(theme.ui(14, weight: 500))
                    .foregroundStyle(settings.promoOptIn ? theme.text : theme.textMuted)
                Text(l10n[.promoPlacesSub])
                    .font(theme.ui(11))
                    .foregroundStyle(theme.textFaint)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(get: { settings.promoOptIn }, set: { toggle($0) }))
                .labelsHidden()
                .tint(theme.accent)
                .accessibilityLabel(l10n[.promoTitle])
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.raised)
        )
    }

    private func toggle(_ on: Bool) {
        settings.setPromoOptIn(on, source: "places")
        guard on else { return }
        Task {
            guard await Reminders.authorization() == .notAsked else { return }
            let granted = await Reminders.requestPermission()
            EventLog.log(.pushPermission(granted: granted, source: "promo"))
        }
    }
}

/// Включить, выключить и выбрать время.
///
/// Если система уведомления запретила, переключатель не врёт: остаётся
/// выключенным, а ниже — объяснение и кнопка в настройки iPhone. Иначе
/// человек включал бы его снова и снова и не понимал, почему ничего не
/// приходит.
struct DailyVerseSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: AppSettings

    @State private var denied = false
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n[.dailyVerseTitle])
                .font(theme.display(24))
                .foregroundStyle(theme.text)

            Text(l10n[.dailyVerseSub])
                .font(theme.ui(13))
                .foregroundStyle(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(settings.dailyVerseEnabled
                     ? l10n(.dailyVerseOn, ClockTime.text(minutes: settings.dailyVerseMinutes, locale: l10n.locale))
                     : l10n[.dailyVerseOff])
                    .font(theme.ui(14))
                    .foregroundStyle(theme.textMuted)
                Spacer()
                Toggle("", isOn: Binding(get: { settings.dailyVerseEnabled }, set: { toggle($0) }))
                    .labelsHidden()
                    .tint(theme.accent)
                    .disabled(asking)
                    .accessibilityLabel(l10n[.dailyVerseTitle])
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Capsule().fill(theme.raised))

            if settings.dailyVerseEnabled {
                DatePicker(l10n[.dailyVerseTime],
                           selection: Binding(
                               get: { ClockTime.date(minutes: settings.dailyVerseMinutes) },
                               set: { settings.dailyVerseMinutes = ClockTime.minutes(from: $0) }),
                           displayedComponents: .hourAndMinute)
                    .wheelStyle()
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()
            }

            if denied {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n[.notifyDenied])
                        .font(theme.ui(13))
                        .foregroundStyle(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = Platform.notificationSettingsURL {
                        Button(l10n[.openSettings]) { openURL(url) }
                            .buttonStyle(GhostButton())
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
        // Человек мог вернуться из настроек iPhone, разрешив уведомления, — или,
        // наоборот, запретив. Флаг сверяется с системой при каждом возвращении.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let authorized = await Reminders.isAuthorized()
            if !authorized, settings.dailyVerseEnabled { settings.dailyVerseEnabled = false }
            if authorized { denied = false }
        }
    }

    private func toggle(_ on: Bool) {
        guard on else {
            settings.dailyVerseEnabled = false
            return
        }
        asking = true
        Task {
            denied = !(await settings.turnOnDailyVerse(source: "places"))
            asking = false
        }
    }
}
