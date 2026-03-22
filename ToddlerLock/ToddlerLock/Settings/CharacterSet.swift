import Foundation

/// Available character sets for letter display in Free Play mode.
enum LetterCharacterSet: String, CaseIterable {
    case arabic = "Arabic"
    case chinese = "Chinese"
    case english = "English"
    case hebrew = "Hebrew"
    case japanese = "Japanese"
    case korean = "Korean"

    /// The characters to display when keys are pressed.
    var characters: [String] {
        switch self {
        case .arabic:
            return ["ا","ب","ت","ث","ج","ح","خ","د","ذ","ر","ز","س","ش","ص","ض","ط","ظ","ع","غ","ف","ق","ك","ل","م","ن","ه","و","ي"]
        case .chinese:
            return ["大","小","人","天","地","日","月","水","火","山","木","花","鸟","鱼","马","牛","羊","猫","狗","龙","星","云","风","雨","雪","虹","心","笑"]
        case .english:
            return ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
        case .hebrew:
            return ["א","ב","ג","ד","ה","ו","ז","ח","ט","י","כ","ל","מ","נ","ס","ע","פ","צ","ק","ר","ש","ת"]
        case .japanese:
            return ["あ","い","う","え","お","か","き","く","け","こ","さ","し","す","せ","そ","た","ち","つ","て","と","な","に","ぬ","ね","の","は","ひ","ふ","へ","ほ"]
        case .korean:
            return ["가","나","다","라","마","바","사","아","자","차","카","타","파","하","거","너","더","러","머","버","서","어","저","처","커","터","퍼","허"]
        }
    }

    /// Get a random character from this set.
    func randomCharacter() -> String {
        characters.randomElement() ?? "?"
    }

    /// Map a keyCode to a character in this set (deterministic per key).
    func character(for keyCode: UInt16) -> String {
        let index = Int(keyCode) % characters.count
        return characters[index]
    }
}
