import CoreText
import Foundation

/// One cell of the grid: a base emoji and, when it takes skin tones, its five variants.
struct EmojiItem: Hashable {
  let emoji: String
  let skins: [String]?
}

struct EmojiGroup {
  let key: String
  let items: [EmojiItem]
}

/// Localized group titles, the recents title and the words search matches, for one locale.
struct EmojiNames {
  let locale: Locale
  let recents: String
  let search: String
  let groups: [String: String]
  /// Base emoji → (label, lowercased label + CLDR keywords).
  let names: [String: (label: String, words: String)]
}

/// The emoji data bundled with the library (built by `scripts/gen-emoji.mjs`), the
/// recents and the skin tone last picked for each emoji.
final class EmojiStore {
  static let shared = EmojiStore()

  private static let recentsKey = "RNEmojiPicker.recents"
  private static let tonesKey = "RNEmojiPicker.tones"
  private static let maxRecents = 24

  /// Emoji older than this are drawn by every iOS the library supports (15.1+ has Emoji 13.1).
  private static let alwaysSupportedVersion = 13.1

  private(set) lazy var groups: [EmojiGroup] = loadGroups()
  private var namesCache: [String: EmojiNames] = [:]
  private let defaults = UserDefaults.standard

  private static var resourceBundle: Bundle {
    let host = Bundle(for: EmojiStore.self)
    if let url = host.url(forResource: "RNEmojiPicker", withExtension: "bundle"),
       let bundle = Bundle(url: url) {
      return bundle
    }
    return host
  }

  private static func json(_ name: String) -> Any? {
    guard let url = resourceBundle.url(forResource: name, withExtension: "json"),
          let data = try? Data(contentsOf: url) else {
      return nil
    }
    return try? JSONSerialization.jsonObject(with: data)
  }

  private func loadGroups() -> [EmojiGroup] {
    guard let raw = Self.json("emoji") as? [[String: Any]] else {
      return []
    }
    return raw.compactMap { group in
      guard let key = group["key"] as? String,
            let emoji = group["emoji"] as? [[String: Any]] else {
        return nil
      }
      let items: [EmojiItem] = emoji.compactMap { entry in
        guard let value = entry["e"] as? String else {
          return nil
        }
        let version = entry["v"] as? Double ?? 0
        if version > Self.alwaysSupportedVersion && !Self.canDraw(value) {
          return nil
        }
        let skins = (entry["s"] as? [String]).flatMap { skins in
          // A tone newer than its base emoji can be missing on its own.
          skins.allSatisfy { version <= Self.alwaysSupportedVersion || Self.canDraw($0) }
            ? skins : nil
        }
        return EmojiItem(emoji: value, skins: skins)
      }
      return EmojiGroup(key: key, items: items)
    }
  }

  /// Whether Apple Color Emoji draws `emoji` as one glyph. An emoji newer than the
  /// system falls apart into its parts (a ZWJ sequence) or falls back to another
  /// font (a new code point), and shows as tofu or a cluster of older emoji.
  static func canDraw(_ emoji: String) -> Bool {
    let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
    let text = NSAttributedString(
      string: emoji,
      attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
    )
    let line = CTLineCreateWithAttributedString(text)
    guard CTLineGetGlyphCount(line) == 1,
          let runs = CTLineGetGlyphRuns(line) as? [CTRun],
          let run = runs.first else {
      return false
    }
    let attributes = CTRunGetAttributes(run) as NSDictionary
    guard let runFont = attributes[kCTFontAttributeName as String] else {
      return false
    }
    // swiftlint:disable:next force_cast
    let name = CTFontCopyPostScriptName(runFont as! CTFont) as String
    var glyph = CGGlyph()
    CTRunGetGlyphs(run, CFRange(location: 0, length: 1), &glyph)
    return name == "AppleColorEmoji" && glyph != 0
  }

  // MARK: Names

  /// The names for `identifier` (`fr`, `pt-BR`, `zh-Hant`…), or English when the
  /// language isn't bundled.
  func names(for identifier: String?) -> EmojiNames {
    let requested = identifier ?? Bundle.main.preferredLocalizations.first ?? "en"
    let language = Self.languageCode(of: requested)
    if let cached = namesCache[language] {
      return cached
    }
    let loaded = Self.loadNames(language) ?? Self.loadNames("en")
    let names = loaded ?? EmojiNames(
      locale: Locale(identifier: "en"), recents: "Frequently Used", search: "Search", groups: [:], names: [:]
    )
    namesCache[language] = names
    return names
  }

  /// `fr` for `fr-CA`, `zh` for `zh-Hant`: the bundled names are per language.
  private static func languageCode(of identifier: String) -> String {
    let locale = Locale(identifier: identifier)
    if #available(iOS 16, *) {
      return locale.language.languageCode?.identifier ?? "en"
    }
    return locale.languageCode ?? "en"
  }

  private static func loadNames(_ language: String) -> EmojiNames? {
    guard let raw = json("names-\(language)") as? [String: Any],
          let names = raw["names"] as? [String: [String]] else {
      return nil
    }
    var parsed: [String: (label: String, words: String)] = [:]
    parsed.reserveCapacity(names.count)
    for (emoji, pair) in names where pair.count == 2 {
      parsed[emoji] = (pair[0], pair[1])
    }
    return EmojiNames(
      locale: Locale(identifier: language),
      recents: raw["recents"] as? String ?? "Frequently Used",
      search: raw["search"] as? String ?? "Search",
      groups: raw["groups"] as? [String: String] ?? [:],
      names: parsed
    )
  }

  /// Emoji whose label or keywords have a word starting with each word of `query`.
  func search(_ query: String, names: EmojiNames) -> [EmojiItem] {
    let terms = query.lowercased(with: names.locale)
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)
    guard !terms.isEmpty else {
      return []
    }
    var labelMatches: [EmojiItem] = []
    var otherMatches: [EmojiItem] = []
    for group in groups {
      for item in group.items {
        guard let entry = names.names[item.emoji] else {
          continue
        }
        let words = entry.words
        let matches = terms.allSatisfy { term in
          words.hasPrefix(term) || words.contains(" " + term)
        }
        guard matches else {
          continue
        }
        // Emoji named after the query first: "cat" lists 🐈 before 😺.
        if entry.label.lowercased(with: names.locale).hasPrefix(terms[0]) {
          labelMatches.append(item)
        } else {
          otherMatches.append(item)
        }
      }
    }
    return labelMatches + otherMatches
  }

  // MARK: Recents and tones

  /// Recently picked emoji, most recent first, exactly as picked (with their tone).
  var recents: [EmojiItem] {
    let values = defaults.stringArray(forKey: Self.recentsKey) ?? []
    return values.map { EmojiItem(emoji: $0, skins: nil) }
  }

  func record(_ emoji: String, base: String?) {
    var values = defaults.stringArray(forKey: Self.recentsKey) ?? []
    values.removeAll { $0 == emoji }
    values.insert(emoji, at: 0)
    defaults.set(Array(values.prefix(Self.maxRecents)), forKey: Self.recentsKey)

    if let base {
      var tones = defaults.dictionary(forKey: Self.tonesKey) as? [String: String] ?? [:]
      tones[base] = emoji
      defaults.set(tones, forKey: Self.tonesKey)
    }
  }

  /// What the grid shows for `item`: the tone picked last time, else the base emoji.
  func displayed(_ item: EmojiItem) -> String {
    guard item.skins != nil else {
      return item.emoji
    }
    let tones = defaults.dictionary(forKey: Self.tonesKey) as? [String: String]
    return tones?[item.emoji] ?? item.emoji
  }
}
