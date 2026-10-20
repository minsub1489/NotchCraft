import Foundation

func L(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: "language") ?? "ko"
    return localized(key, language:language)
}

func localized(_ key:String, language:String) -> String {
    #if SWIFT_PACKAGE
    let root = Bundle.module
    #else
    let root = Bundle.main
    #endif
    let bundle = root.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? root
    return bundle.localizedString(forKey: key, value: key, table: nil)
}
