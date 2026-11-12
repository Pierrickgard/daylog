import Foundation

/// The app speaks English, or French when it is the user's first language.
enum L10n {
    static let lang: String = (Locale.preferredLanguages.first ?? "en").hasPrefix("fr") ? "fr" : "en"
    static let locale = Locale(identifier: lang == "fr" ? "fr_FR" : "en_US")

    static func t(_ en: String, _ fr: String) -> String { lang == "fr" ? fr : en }
}
