import Foundation

/// Строки интерфейса. Сейчас язык один — английский.
///
/// Таблица в коде, а не `.strings`-файлы, по одной причине: язык интерфейса
/// здесь выбирает человек в настройках приложения, а не система. Стандартный
/// механизм локализации подставляет язык устройства и заставляет держать
/// отдельный `Bundle` на каждый `lproj`; здесь же достаточно словаря, который
/// к тому же виден на ревью целиком и не может «потерять ключ» в рантайме.
///
/// Порядок значений в каждой строке один: по языкам из `AppLocale` (сейчас en).
///
/// ФАЙЛ СГЕНЕРИРОВАН `tools/i18n/gen_strings.py` — не править руками: правки
/// пропадут при следующей сборке. Образцы стихов (`demoVerse`, `pauseVerse`) берутся
/// из корпуса, а не набираются.
public struct L10n: Sendable, Hashable {
    public let locale: AppLocale

    public init(_ locale: AppLocale) {
        self.locale = locale
    }

    public subscript(_ key: Key) -> String {
        let row = L10n.table[key] ?? [""]
        let value = row[min(index, row.count - 1)]
        guard value.isEmpty else { return value }
        // Пустая строка означает недостающий перевод: показываем первую колонку,
        // а не пустоту. Заметить это на глаз проще, чем дыру в интерфейсе.
        return row[0]
    }

    /// Подстановка чисел: «Сейчас 3 из 7».
    public func callAsFunction(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: self[key], arguments: arguments)
    }

    /// Число со словом в нужной форме: «1 day», «45 days».
    ///
    /// Формы лежат в строке таблицы через вертикальную черту: у английского две
    /// (единственное и множественное).
    public func count(_ number: Int, _ key: Key) -> String {
        let forms = self[key].split(separator: "|").map(String.init)
        let index: Int
        switch locale {
        case .en:
            index = number == 1 ? 0 : 1
        }
        return "\(number) \(forms[min(index, forms.count - 1)])"
    }

    public enum Key: String, Sendable, Hashable, CaseIterable {
        case heroTitle, heroSubtitle, heroAction, heroEditions, languageTitle, languageSubtitle
        case next, themesTitle, themesSubtitle, themesEmpty, themesPicked, widgetTitle
        case widgetSubtitle, widgetAction, widgetLater, pauseEyebrow, pauseTitle, pauseSubtitle
        case pauseAction, pauseWait, pauseClose, pauseNoApp, obVerseEyebrow, obVerseCta
        case obVerseTrust, goalTitle, goalLead, goalHint, goalComfort, goalComfortSub
        case goalDaily, goalDailySub, goalFeed, goalFeedSub, goalBeauty, goalBeautySub
        case obThemesTitle, obThemesSub, obThemesCounter, obTimeEyebrow, obTimeTitle, obTimeSub
        case obTimeLater, obFeedTitle, obFeedSub, obFeedInsight, feedUnderOne, feedOneToTwo
        case feedTwoToFour, feedOverFour, obLookEyebrow, obLookTitle, obLookSub, obFirstTitle
        case obFirstSub, obFirstCta, obFirstSentTitle, obFirstSentSub, obIconEyebrow, obIconTitle
        case obIconSub, obIconKeep, obWidgetEyebrow, obWidgetTitle, obWidgetSub, obWidgetCta
        case obWidgetLater, obDoneEyebrow, obDoneTitle, obDoneFooter, obWhyLead, obWhyNumber
        case obWhyQuestion, obWhySource, obWhyCta, versesUnit, daysUnit, fontsUnit
        case iconsUnit, pwTitle, pwTitleGeneric, pwSub, pwComfortEyebrow, pwComfortTitle
        case pwComfortSub, pwDailyEyebrow, pwDailyTitle, pwDailySub, chipDailyVerse, pwFeedEyebrow
        case pwFeedTitle, pwFeedSub, pwBeautyTitle, pwBeautySub, pwBeautySubNoPick, unlockStandBy
        case unlockWallpaper, unlockSets, unlockPictures, unlockFonts, unlockIcons, planWeek
        case planMonth, planYear, planWeekNote, planMonthNote, planYearNote, pwTrialCta
        case pwSubscribeCta, pwAfterTrial, pwCancelAnytime, pwHowTrial, pwRestore, pwTerms
        case pwPrivacy, standByLocked, proEndedTitle, proEndedBody, proEndedCta, stepLock1
        case stepLock1Hint, stepLock2, stepLock2Hint, stepLock3, stepLock3Hint, stepHome1
        case stepHome1Hint, stepHome2, stepHome2Hint, stepHome3, stepHome3Hint, stepControl1
        case stepControl1Hint, stepControl2, stepControl2Hint, stepControl3, stepControl3Hint, stepStandBy1
        case stepStandBy1Hint, stepStandBy2, stepStandBy2Hint, stepStandBy3, stepStandBy3Hint, stepWatch1
        case stepWatch1Hint, stepWatch2, stepWatch2Hint, stepWatch3, stepWatch3Hint, stepWallpaper1
        case stepWallpaper1Hint, stepWallpaper2, stepWallpaper2Hint, stepWallpaper3, stepWallpaper3Hint, stepPause1
        case stepPause1Hint, stepPause2, stepPause2Hint, stepPause3, stepPause3Hint, back
        case notNow, continueAction, openShortcuts, installShortcut, manageSubscription, coachSwipe
        case coachAreas, coachAppStyle, coachSwitchToWidgets, coachWidgetStyle, coachPlaces, coachMarkDone
        case coachSkip, coachNext, coachDone, colourSets, imageSets, tabToday
        case appIconTitle, iconDefault, iconNight, widgetDisplayName, widgetDescription, controlDisplayName
        case controlDescription, depthHint, surfaceLock, surfaceHome, surfaceControl, surfaceWallpaper
        case surfacePause, howLock, howHome, howControl, howStandBy, howWatch
        case howWallpaper, noteAuto, noteSecondRelease, noteManual, ctaLock, ctaHome
        case ctaControl, ctaStandBy, ctaWatch, ctaWallpaper, ctaPause, areaApp
        case areaWidgets, areaLock, styleNight, styleParchment, styleAmber, styleInk
        case styleDawn, styleOpal, styleCoal, sizeSmall, sizeMedium, sizeLarge
        case lengthShort, lengthFull, alignLeading, alignCenter, formatStory, formatSquare
        case formatWallpaper, backToDaily, share, contextPill, placesTitle, placesProgress
        case groupScreens, groupMoment, lookTitle, preview, size, font
        case languageAndEdition, systemFont, verseLength, alignment, lockColorNote, appIcon
        case shareTitle, sendAction, wordmark, context, understood, close
        case openSettings, markDone, paywallTitle, subscribe, restore, paywallLegal
        case perkSurfaces, perkStyles, perkIcons, demoVerse, demoReference, pauseVerse
        case pauseReference, obNotifyEyebrow, notifyNow, obTrackEyebrow, obTrackTitle, obTrackSub
        case obTrackCta, dailyVerseTitle, dailyVerseOn, dailyVerseOff, dailyVerseSub, dailyVerseTime
        case notifyDenied, comeback3Title, comeback3Body, comeback7Title, comeback7Body, widgetGoneTitle
        case widgetGoneBody, secondHomeTitle, secondHomeBody, secondLockTitle, secondLockBody, cancelTitle
        case cancelSub, cancelSkip, cancelThanks, cancelSend, reasonPrice, reasonUnused
        case reasonFreeEnough, reasonNotWhat, reasonJustLooking, reasonOther, welcomeEyebrow, welcomeTitle
        case welcomeSub, welcomeTerms, welcomeCta, welcomeNo, pwPickedEyebrow, analyticsTitle
        case analyticsNote, wnIconsEyebrow, wnIconsTitle, wnIconsSub, wnFree, wnSkip
        case wnPicturesEyebrow, wnPicturesTitle, wnPicturesSub, wnSetPicture, wnUnlockPicture, wnDailyTitle
        case wnDailySub, wnDailyCta, wnDone, promoTitle, promoSub, promoPlacesSub
        case rateApp, pushTokenCopied, corpusFailedTitle, corpusFailedHint, iconDawn, iconLight
        case showOriginal, planTrialNote, sceneHimalaya, sceneGanga, sceneTemple, sceneDiya
        case sceneLotus, sceneRangoli, sceneMandala, iconLotus, iconOm, iconTemple
        case iconMandala, styleSaffron
    }

    // Порядок в строке: en
    private static let table: [Key: [String]] = [
        .heroTitle: ["The verse where you already look"],
        .heroSubtitle: ["Lock screen, home screen, bedside table. Nothing to remember — the verse is simply there."],
        .heroAction: ["Light it"],
        .heroEditions: ["Sanskrit original · Besant translation"],
        .languageTitle: ["Text and translation"],
        .languageSubtitle: ["Sanskrit original with an English translation"],
        .next: ["Next"],
        .themesTitle: ["What do you need right now"],
        .themesSubtitle: ["Pick one or several. The verses will follow"],
        .themesEmpty: ["Choose nothing and you get every verse"],
        .themesPicked: ["%d of %d selected"],
        .widgetTitle: ["Add the widget"],
        .widgetSubtitle: ["The lock screen is the most visible place on your phone. Free, forever"],
        .widgetAction: ["Show me how"],
        .widgetLater: ["I’ll do it later"],
        .pauseEyebrow: ["Only here"],
        .pauseTitle: ["A pause before the feed"],
        .pauseSubtitle: ["You open a social app and a verse meets you first. Not another feed — one second where you were about to scroll"],
        .pauseAction: ["Turn on"],
        .pauseWait: ["Wait a second"],
        .pauseClose: ["Close"],
        .pauseNoApp: ["No app is chosen in the automation. Open it in Shortcuts and set one in the “Verse pause” action — then the button will take you straight back"],
        .obVerseEyebrow: ["VERSE FOR TODAY"],
        .obVerseCta: ["I want to see it more often"],
        .obVerseTrust: ["No account · no ads · works offline"],
        .goalTitle: ["What do you need most right now?"],
        .goalLead: ["Pick one — we will fit the verses, the screen and Pro to it"],
        .goalHint: ["Everything else opens up later, in Places"],
        .goalComfort: ["Comfort when it is hard"],
        .goalComfortSub: ["verses for what is on your heart"],
        .goalDaily: ["Keep the Gita close every day"],
        .goalDailySub: ["one verse at the time you choose"],
        .goalFeed: ["Scroll the feed less"],
        .goalFeedSub: ["a verse before social media"],
        .goalBeauty: ["Something beautiful on my phone"],
        .goalBeautySub: ["your own verse style and icon"],
        .obThemesTitle: ["What is on your heart right now?"],
        .obThemesSub: ["Pick it, and the verse on your screen will speak to it"],
        .obThemesCounter: ["%d selected · %@ for you"],
        .obTimeEyebrow: ["EVERY DAY"],
        .obTimeTitle: ["When should the verse arrive?"],
        .obTimeSub: ["One verse at the same time each day, no ads. The first one arrives right now, on the next step"],
        .obTimeLater: ["I will decide later"],
        .obFeedTitle: ["How much of your day goes to the feed?"],
        .obFeedSub: ["Roughly — the answer stays on your phone"],
        .obFeedInsight: ["≈ %@ a year. A verse won’t give them back — but it will meet you before the feed, every time you pick up your phone"],
        .feedUnderOne: ["Under an hour"],
        .feedOneToTwo: ["1–2 hours"],
        .feedTwoToFour: ["2–4 hours"],
        .feedOverFour: ["Over 4 hours"],
        .obLookEyebrow: ["YOUR LOOK"],
        .obLookTitle: ["How should your verse look?"],
        .obLookSub: ["A color or a picture — this is how it will look on your lock screen and in widgets"],
        .obFirstTitle: ["Your first verse, right now"],
        .obFirstSub: ["Tap, and it arrives as a notification — just as it will every day"],
        .obFirstCta: ["Send my first verse"],
        .obFirstSentTitle: ["Your first verse is here ↑"],
        .obFirstSentSub: ["It will come like this every day at %@ — change the time in Places. It is the same verse as on your screen now"],
        .obIconEyebrow: ["YOUR DEEPAM"],
        .obIconTitle: ["Which icon will it be?"],
        .obIconSub: ["It changes right away — take a look at your home screen. Paid ones switch on with Pro"],
        .obIconKeep: ["Keep the main one"],
        .obWidgetEyebrow: ["THE MAIN SPOT"],
        .obWidgetTitle: ["Now, onto the lock screen"],
        .obWidgetSub: ["Three taps, and the verse is there every time you glance at your phone"],
        .obWidgetCta: ["Show me how"],
        .obWidgetLater: ["I will add it later"],
        .obDoneEyebrow: ["✓ WIDGET IN PLACE"],
        .obDoneTitle: ["Done — the verse is on your screen"],
        .obDoneFooter: ["It will greet you every time you pick up your phone"],
        .obWhyLead: ["This year you will pick up your phone"],
        .obWhyNumber: ["35,000 times"],
        .obWhyQuestion: ["How many will start with a verse?"],
        .obWhySource: ["On average a phone is unlocked 96 times a day — about 35,000 a year"],
        .obWhyCta: ["Let every one"],
        .versesUnit: ["verse|verses"],
        .daysUnit: ["day|days"],
        .fontsUnit: ["typeface|typefaces"],
        .iconsUnit: ["icon|icons"],
        .pwTitle: ["Let the light keep shining"],
        .pwTitleGeneric: ["Light up the whole phone"],
        .pwSub: ["Deepam has no ads. It runs on the people who use it — a subscription helps it keep shining"],
        .pwComfortEyebrow: ["FOR WHAT IS ON YOUR HEART"],
        .pwComfortTitle: ["A verse close by when it is hard"],
        .pwComfortSub: ["At night on your nightstand in StandBy, by day on your lock screen, in a picture that calms"],
        .pwDailyEyebrow: ["EVERY DAY AT %@"],
        .pwDailyTitle: ["The verse wherever you look"],
        .pwDailySub: ["You pick up your phone 35,000 times a year. With Pro the verse meets you on the nightstand and on your wallpaper too"],
        .chipDailyVerse: ["Verse of the day"],
        .pwFeedEyebrow: ["THE PAUSE IS FREE FOREVER"],
        .pwFeedTitle: ["Less feed, more Gita"],
        .pwFeedSub: ["The pause before social media stays free. Pro puts the verse on every screen, looking the way you like"],
        .pwBeautyTitle: ["Make it yours"],
        .pwBeautySub: ["The icon and picture you chose switch on with Pro. And with them, every color set and picture, %@ and %@"],
        .pwBeautySubNoPick: ["With Pro: every color set and picture, %@ and %@"],
        .unlockStandBy: ["StandBy"],
        .unlockWallpaper: ["Wallpaper"],
        .unlockSets: ["All color sets"],
        .unlockPictures: ["All pictures"],
        .unlockFonts: ["Typefaces"],
        .unlockIcons: ["App icons"],
        .planWeek: ["Week"],
        .planMonth: ["Month"],
        .planYear: ["Year"],
        .planWeekNote: ["per week"],
        .planMonthNote: ["per month"],
        .planYearNote: ["per year"],
        .pwTrialCta: ["Start %@ free"],
        .pwSubscribeCta: ["Subscribe for %@"],
        .pwAfterTrial: ["Then %@ · cancel anytime"],
        .pwCancelAnytime: ["Cancel anytime"],
        .pwHowTrial: ["How the free trial works"],
        .pwRestore: ["Restore purchases"],
        .pwTerms: ["Terms of Use"],
        .pwPrivacy: ["Privacy Policy"],
        .standByLocked: ["StandBy comes with Deepam Pro"],
        .proEndedTitle: ["Your subscription has ended"],
        .proEndedBody: ["The look is back to the free version. StandBy and the Pro color sets, pictures, typefaces and icons return with Deepam Pro."],
        .proEndedCta: ["Get Deepam Pro back"],
        .stepLock1: ["Touch and hold the Lock Screen"],
        .stepLock1Hint: ["until the Customize button appears"],
        .stepLock2: ["Tap Customize, then Lock Screen"],
        .stepLock2Hint: ["the editor opens"],
        .stepLock3: ["Add the Deepam widget below the clock"],
        .stepLock3Hint: ["choose the rectangular size"],
        .stepHome1: ["Touch and hold an empty area of the Home Screen"],
        .stepHome1Hint: ["the icons start to jiggle"],
        .stepHome2: ["Tap + in the top-left corner"],
        .stepHome2Hint: ["the widget gallery opens"],
        .stepHome3: ["Find Deepam and pick a size"],
        .stepHome3Hint: ["the medium one fits the whole verse"],
        .stepControl1: ["Open Control Center and tap +"],
        .stepControl1Hint: ["iOS 18 required: add it in editing mode"],
        .stepControl2: ["Tap Add a Control"],
        .stepControl2Hint: ["a list opens"],
        .stepControl3: ["Find Deepam in the list"],
        .stepControl3Hint: ["the button goes wherever you place it"],
        .stepStandBy1: ["Put the phone on a charger on its side"],
        .stepStandBy1Hint: ["the screen switches to StandBy"],
        .stepStandBy2: ["Swipe to the right-hand panel"],
        .stepStandBy2Hint: ["that is where the widgets live"],
        .stepStandBy3: ["Touch and hold the panel, then add Deepam"],
        .stepStandBy3Hint: ["the widget stays visible all night"],
        .stepWatch1: ["Wait for the second release"],
        .stepWatch1Hint: ["the watch app is not out yet"],
        .stepWatch2: ["Update Deepam when it arrives"],
        .stepWatch2Hint: ["we will say so in the app"],
        .stepWatch3: ["Add the complication to your watch face"],
        .stepWatch3Hint: ["the verse shows when you raise your wrist"],
        .stepWallpaper1: ["Save the wallpaper with the verse"],
        .stepWallpaper1Hint: ["Share → Save Image"],
        .stepWallpaper2: ["Open Settings → Wallpaper"],
        .stepWallpaper2Hint: ["tap Add New Wallpaper"],
        .stepWallpaper3: ["Choose Photos and the saved image"],
        .stepWallpaper3Hint: ["the verse changes once a day"],
        .stepPause1: ["Open Shortcuts → Automation"],
        .stepPause1Hint: ["the app is already on your phone"],
        .stepPause2: ["Create an App automation → Is Opened"],
        .stepPause2Hint: ["pick the social apps you open most"],
        .stepPause3: ["Add the “Verse pause” action"],
        .stepPause3Hint: ["in the action’s field pick the same app — that is where it returns you"],
        .back: ["Back"],
        .notNow: ["Not now"],
        .continueAction: ["Continue"],
        .openShortcuts: ["Open Shortcuts"],
        .installShortcut: ["Add the ready shortcut"],
        .manageSubscription: ["Subscription"],
        .coachSwipe: ["Swipe up for another verse. Tap the date to come back to today’s"],
        .coachAreas: ["Three places the verse meets you: the app, widgets and the lock screen. Each is set up separately"],
        .coachAppStyle: ["Pick a color or a picture — that is how the app itself will look"],
        .coachSwitchToWidgets: ["Now switch to Widgets"],
        .coachWidgetStyle: ["Widgets have a look of their own. Pick a color or a picture for them too"],
        .coachPlaces: ["Tap a tile and I will show you how to put the verse there"],
        .coachMarkDone: ["And flip the switch once you have done it"],
        .coachSkip: ["Skip"],
        .coachNext: ["Next"],
        .coachDone: ["Done"],
        .colourSets: ["Color"],
        .imageSets: ["Image"],
        .tabToday: ["Today"],
        .appIconTitle: ["App icon"],
        .iconDefault: ["Default"],
        .iconNight: ["Night"],
        .widgetDisplayName: ["Verse of the day"],
        .widgetDescription: ["A verse for every day, where you already look"],
        .controlDisplayName: ["Verse of the day"],
        .controlDescription: ["A Control Center button that opens today’s verse"],
        .depthHint: ["Showing verse %d back from today"],
        .surfaceLock: ["Lock screen"],
        .surfaceHome: ["Home screen"],
        .surfaceControl: ["Control Center"],
        .surfaceWallpaper: ["Wallpaper"],
        .surfacePause: ["Pause before the feed"],
        .howLock: ["Widget on the lock screen"],
        .howHome: ["Widget on the home screen"],
        .howControl: ["Button in Control Center"],
        .howStandBy: ["Widget in StandBy"],
        .howWatch: ["Complication on Apple Watch"],
        .howWallpaper: ["Wallpaper with a verse"],
        .noteAuto: ["The widget will tick itself in Places"],
        .noteSecondRelease: ["Coming in the second release"],
        .noteManual: ["Tick it in Places when you are done"],
        .ctaLock: ["Put it on the lock screen"],
        .ctaHome: ["Add to the home screen"],
        .ctaControl: ["Add to Control Center"],
        .ctaStandBy: ["Turn on in StandBy"],
        .ctaWatch: ["Show on Apple Watch"],
        .ctaWallpaper: ["Set the wallpaper"],
        .ctaPause: ["Turn on the pause before the feed"],
        .areaApp: ["App"],
        .areaWidgets: ["Widgets"],
        .areaLock: ["Lock screen"],
        .styleNight: ["Night"],
        .styleParchment: ["Parchment"],
        .styleAmber: ["Amber"],
        .styleInk: ["Ink"],
        .styleDawn: ["Dawn"],
        .styleOpal: ["Opal"],
        .styleCoal: ["Coal"],
        .sizeSmall: ["Small"],
        .sizeMedium: ["Medium"],
        .sizeLarge: ["Large"],
        .lengthShort: ["Short"],
        .lengthFull: ["Full"],
        .alignLeading: ["Left"],
        .alignCenter: ["Centered"],
        .formatStory: ["Story"],
        .formatSquare: ["Square"],
        .formatWallpaper: ["Wallpaper"],
        .backToDaily: ["back to today’s verse"],
        .share: ["Share"],
        .contextPill: ["Who speaks, and to whom"],
        .placesTitle: ["Places"],
        .placesProgress: ["%d of %d — the more places, the more often a verse catches your eye"],
        .groupScreens: ["On screens"],
        .groupMoment: ["In the moment"],
        .lookTitle: ["Look"],
        .preview: ["Preview"],
        .size: ["Size"],
        .font: ["Font"],
        .languageAndEdition: ["Text and translation"],
        .systemFont: ["System"],
        .verseLength: ["Verse length"],
        .alignment: ["Alignment"],
        .lockColorNote: ["iOS sets the color here — the widget adapts to your wallpaper"],
        .appIcon: ["App icon"],
        .shareTitle: ["Share"],
        .sendAction: ["Send"],
        .wordmark: ["Deepam mark"],
        .context: ["Context"],
        .understood: ["Got it"],
        .close: ["Close"],
        .openSettings: ["Open Settings"],
        .markDone: ["Mark as done"],
        .paywallTitle: ["The verse everywhere you look"],
        .subscribe: ["Subscribe"],
        .restore: ["Restore purchases"],
        .paywallLegal: ["The subscription renews automatically. Cancel any time in your Apple ID settings."],
        .perkSurfaces: ["StandBy and verse wallpapers"],
        .perkStyles: ["Every style set for the app, widgets and lock screen"],
        .perkIcons: ["A choice of app icons"],
        .demoVerse: ["As a lamp in a windless place flickereth not, to such is likened the Yogî of subdued thought, absorbed in the yoga of the Self."],
        .demoReference: ["Bhagavad Gita 6.19"],
        .pauseVerse: ["As often as the wavering and unsteady mind goeth forth, so often reining it in, let him bring it under the control of the Self."],
        .pauseReference: ["Bhagavad Gita 6.26"],
        .obNotifyEyebrow: ["VERSE OF THE DAY"],
        .notifyNow: ["now"],
        .obTrackEyebrow: ["ONE QUESTION"],
        .obTrackTitle: ["Your iPhone is about to ask about tracking"],
        .obTrackSub: ["Deepam finds people through ads. If you allow it, we learn which ad brought you here — and stop paying for the ones that don’t work. Your verses and answers are never shared. You can change this in iPhone Settings"],
        .obTrackCta: ["Continue"],
        .dailyVerseTitle: ["Verse of the day as a notification"],
        .dailyVerseOn: ["Every day at %@"],
        .dailyVerseOff: ["Off"],
        .dailyVerseSub: ["The same verse as on Today, at the time you choose"],
        .dailyVerseTime: ["Time"],
        .notifyDenied: ["Notifications for Deepam are turned off in iPhone Settings"],
        .comeback3Title: ["Today’s verse is waiting"],
        .comeback3Body: ["One quiet minute — and a line to carry with you all day."],
        .comeback7Title: ["A week without a verse"],
        .comeback7Body: ["Put it on your lock screen and it will greet you on its own — no app needed."],
        .widgetGoneTitle: ["Has your verse left the screen?"],
        .widgetGoneBody: ["The Deepam widget hasn’t shown up for a while. Putting it back takes twenty seconds."],
        .secondHomeTitle: ["Your verse is on the lock screen"],
        .secondHomeBody: ["Add it to your Home Screen too — it stays in sight all day. Twenty seconds."],
        .secondLockTitle: ["Your verse is on the Home Screen"],
        .secondLockBody: ["Add it to your lock screen too — you’ll see it without even unlocking."],
        .cancelTitle: ["Your free trial is cancelled"],
        .cancelSub: ["You keep access until the trial ends. What didn’t work? You can pick more than one."],
        .cancelSkip: ["Skip"],
        .cancelThanks: ["Thank you — this really helps"],
        .cancelSend: ["Send"],
        .reasonPrice: ["Too expensive"],
        .reasonUnused: ["I rarely use it"],
        .reasonFreeEnough: ["The free version is enough"],
        .reasonNotWhat: ["Not what I was looking for"],
        .reasonJustLooking: ["I just wanted to look around"],
        .reasonOther: ["Something else"],
        .welcomeEyebrow: ["A WELCOME GIFT"],
        .welcomeTitle: ["Your first year of Pro for %@"],
        .welcomeSub: ["Instead of %@. Every background, color set and font, StandBy and wallpapers"],
        .welcomeTerms: ["Paid once for the first year, then %@ a year. Renews automatically — cancel any time in your Apple ID settings"],
        .welcomeCta: ["Get it for %@"],
        .welcomeNo: ["No, thanks"],
        .pwPickedEyebrow: ["YOUR PICK"],
        .analyticsTitle: ["Help improve Deepam"],
        .analyticsNote: ["Anonymous stats: which screens people open and where they get stuck. No verse text and none of your answers."],
        .wnIconsEyebrow: ["NEW IN DEEPAM"],
        .wnIconsTitle: ["Five new icons"],
        .wnIconsSub: ["Night is free for everyone: tap it and it’s on your home screen. The other four come with Pro"],
        .wnFree: ["free"],
        .wnSkip: ["Skip"],
        .wnPicturesEyebrow: ["NEW PICTURES"],
        .wnPicturesTitle: ["Four new pictures"],
        .wnPicturesSub: ["A background for your verse in the app, widgets and wallpaper. Tap to see it with your verse"],
        .wnSetPicture: ["Use as background"],
        .wnUnlockPicture: ["Unlock with Pro"],
        .wnDailyTitle: ["Let the verse come to you"],
        .wnDailySub: ["One notification a day at %@ — the same verse as on your screen. No ads. Change the time in Places"],
        .wnDailyCta: ["Send me a verse every day"],
        .wnDone: ["Done"],
        .promoTitle: ["News and updates"],
        .promoSub: ["Now and then — new icons, pictures and offers. Turn it off any time in Places"],
        .promoPlacesSub: ["New features and offers"],
        .rateApp: ["Rate Deepam"],
        .pushTokenCopied: ["Push token copied"],
        .corpusFailedTitle: ["Could not read the verses"],
        .corpusFailedHint: ["Reinstall the app"],
        .iconDawn: ["Dawn"],
        .iconLight: ["Light"],
        .showOriginal: ["Show the Sanskrit text"],
        .planTrialNote: ["%@ free"],
        .sceneHimalaya: ["Himalaya"],
        .sceneGanga: ["Ganga"],
        .sceneTemple: ["Temple"],
        .sceneDiya: ["Diya"],
        .sceneLotus: ["Lotus"],
        .sceneRangoli: ["Rangoli"],
        .sceneMandala: ["Mandala"],
        .iconLotus: ["Lotus"],
        .iconOm: ["Om"],
        .iconTemple: ["Temple"],
        .iconMandala: ["Mandala"],
        .styleSaffron: ["Saffron"],
    ]
}

extension L10n {
    /// Название состояния для чипов в онбординге.
    ///
    /// Состояния лежат в корпусе одинаковыми во всех языках — по ним
    /// фильтруется пул, и общий идентификатор здесь правильный. Но показывать
    /// его нельзя: идентификаторы русские. Отдельная таблица, а не ключи в общем
    /// перечислении, потому что список задаёт корпус, а не код; тест сверяет
    /// одно с другим.
    public func theme(_ id: String) -> String {
        guard let row = L10n.themes[id] else { return id }
        return row[min(index, row.count - 1)]
    }

    /// Порядок значений тот же: en.
    static let themes: [String: [String]] = [
        "бессонница": ["Sleeplessness"],
        "благодарность": ["Gratitude"],
        "вина": ["Regret"],
        "доверие": ["Surrender"],
        "любовь": ["Devotion"],
        "надежда": ["Hope"],
        "начало дела": ["A new start"],
        "немощь": ["Weakness"],
        "одиночество": ["Loneliness"],
        "прощение": ["Forgiveness"],
        "решение": ["A decision"],
        "сомнение": ["Doubt"],
        "страх": ["Fear"],
        "тревога": ["Anxiety"],
        "усталость": ["Tiredness"],
        "утрата": ["Loss"],
    ]

    /// Номер языка в строке таблицы.
    var index: Int {
        switch locale {
        case .en: 0
        }
    }

    /// Название поверхности. Отдельный метод, потому что у StandBy и Apple Watch
    /// переводить нечего — это имена продуктов Apple.
    public func name(_ surface: Surface) -> String {
        surface.titleKey.map { self[$0] } ?? surface.untranslatedTitle
    }

    /// Дата для макета экрана блокировки.
    ///
    /// Число условное — как и 9:41 на всех снимках Apple, — но написано оно
    /// должно быть на языке интерфейса.
    public var mockDate: String {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: 2025, month: 9, day: 3))
        else { return "" }
        return date.formatted(
            .dateTime.weekday(.wide).day().month(.wide)
                .locale(locale.formattingLocale)
        )
    }
}
