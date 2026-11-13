import UIKit

/// The picker: search on top, the grid, and a category bar, in a popover anchored to
/// a rect of the app's window. Every background is clear, so the popover's own
/// material shows through: Liquid Glass on iOS 26, the system blur before.
@objc(RNEmojiPickerController)
public final class EmojiPickerController: UIViewController {

  private enum Section: Hashable {
    case recents
    case group(String)
    case results
  }

  private static let columns = 8
  private static let cellSize: CGFloat = 40
  private static let maxSize = CGSize(width: 8 * 40 + 24, height: 400)

  private let store = EmojiStore.shared
  private let names: EmojiNames
  private let onFinish: (String?) -> Void
  private var result: String?
  private var finished = false

  private var sections: [(section: Section, items: [EmojiItem])] = []
  private var browseSections: [(section: Section, items: [EmojiItem])] = []
  private var isSearching = false

  private let searchField = UISearchTextField()
  private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
  private let categoryBar = UIStackView()
  private var categoryButtons: [(section: Section, button: UIButton)] = []

  // MARK: Presentation

  /// Presents the picker from `presenter`, its arrow pointing at `anchor` (in window
  /// coordinates). `onFinish` runs once, with the emoji picked or nil.
  @objc public static func present(
    from presenter: UIViewController,
    anchor: CGRect,
    tintColor: UIColor?,
    interfaceStyle: UIUserInterfaceStyle,
    locale: String?,
    onFinish: @escaping (String?) -> Void
  ) {
    let picker = EmojiPickerController(names: EmojiStore.shared.names(for: locale), onFinish: onFinish)
    picker.modalPresentationStyle = .popover
    picker.overrideUserInterfaceStyle = interfaceStyle
    if let tintColor {
      picker.view.tintColor = tintColor
    }

    let host = presenter.view!
    let window = host.window
    var rect = window.map { host.convert(anchor, from: $0) } ?? anchor
    if rect.isEmpty || rect.isNull {
      rect = CGRect(x: host.bounds.midX, y: host.bounds.midY, width: 1, height: 1)
    }
    let bounds = host.bounds
    picker.preferredContentSize = CGSize(
      width: min(maxSize.width, bounds.width - 16),
      height: min(maxSize.height, bounds.height * 0.6)
    )

    if let popover = picker.popoverPresentationController {
      popover.sourceView = host
      popover.sourceRect = rect
      popover.permittedArrowDirections = [.up, .down]
      popover.delegate = picker
    }
    presenter.present(picker, animated: true)
  }

  init(names: EmojiNames, onFinish: @escaping (String?) -> Void) {
    self.names = names
    self.onFinish = onFinish
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // However it went away (a pick, a tap outside, its presenter dismissed), once.
    guard !finished, presentingViewController == nil || isBeingDismissed else {
      return
    }
    finished = true
    onFinish(result)
  }

  private func pick(_ emoji: String, base: String?) {
    guard result == nil else {
      return
    }
    result = emoji
    store.record(emoji, base: base)
    UISelectionFeedbackGenerator().selectionChanged()
    dismiss(animated: true)
  }

  // MARK: Views

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    searchField.delegate = self
    searchField.placeholder = names.search
    searchField.returnKeyType = .done
    searchField.autocorrectionType = .no
    searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
    searchField.accessibilityIdentifier = "emoji-picker-search"

    collectionView.backgroundColor = .clear
    collectionView.delegate = self
    collectionView.dataSource = self
    collectionView.keyboardDismissMode = .onDrag
    collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseIdentifier)
    collectionView.register(
      SectionHeader.self,
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: SectionHeader.reuseIdentifier
    )
    collectionView.accessibilityIdentifier = "emoji-picker-grid"
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
    longPress.minimumPressDuration = 0.35
    collectionView.addGestureRecognizer(longPress)

    categoryBar.axis = .horizontal
    categoryBar.distribution = .fillEqually

    for subview in [searchField, collectionView, categoryBar] as [UIView] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }
    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      searchField.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
      searchField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
      searchField.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),

      collectionView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
      collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: categoryBar.topAnchor),

      categoryBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
      categoryBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
      categoryBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -6),
      categoryBar.heightAnchor.constraint(equalToConstant: 36),
    ])

    loadSections()
    buildCategoryBar()
  }

  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateSelectedCategory()
  }

  private func loadSections() {
    var all: [(section: Section, items: [EmojiItem])] = []
    let recents = store.recents
    if !recents.isEmpty {
      all.append((.recents, recents))
    }
    for group in store.groups where !group.items.isEmpty {
      all.append((.group(group.key), group.items))
    }
    browseSections = all
    sections = all
  }

  private func makeLayout() -> UICollectionViewLayout {
    UICollectionViewCompositionalLayout { [weak self] _, environment in
      let width = environment.container.effectiveContentSize.width - 16
      let columns = max(1, min(Self.columns, Int(width / Self.cellSize)))
      let item = NSCollectionLayoutItem(
        layoutSize: .init(widthDimension: .fractionalWidth(1 / CGFloat(columns)), heightDimension: .absolute(Self.cellSize))
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(Self.cellSize)),
        subitem: item,
        count: columns
      )
      let section = NSCollectionLayoutSection(group: group)
      section.contentInsets = .init(top: 0, leading: 8, bottom: 8, trailing: 8)
      if self?.isSearching == false {
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(28)),
          elementKind: UICollectionView.elementKindSectionHeader,
          alignment: .top
        )
        section.boundarySupplementaryItems = [header]
      }
      return section
    }
  }

  private func title(for section: Section) -> String {
    switch section {
    case .recents:
      return names.recents
    case let .group(key):
      return names.groups[key] ?? key
    case .results:
      return ""
    }
  }

  private static func symbol(for section: Section) -> String {
    switch section {
    case .recents: return "clock"
    case .group("smileys-emotion"): return "face.smiling"
    case .group("people-body"): return "hand.raised"
    case .group("animals-nature"): return "leaf"
    case .group("food-drink"): return "fork.knife"
    case .group("travel-places"): return "car"
    case .group("activities"): return "sportscourt"
    case .group("objects"): return "lightbulb"
    case .group("symbols"): return "heart"
    case .group("flags"): return "flag"
    default: return "circle"
    }
  }

  private func buildCategoryBar() {
    for (index, entry) in browseSections.enumerated() {
      let button = UIButton(type: .system)
      let configuration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
      button.setImage(UIImage(systemName: Self.symbol(for: entry.section), withConfiguration: configuration), for: .normal)
      button.accessibilityLabel = title(for: entry.section)
      button.tag = index
      button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
      categoryBar.addArrangedSubview(button)
      categoryButtons.append((entry.section, button))
    }
  }

  @objc private func categoryTapped(_ sender: UIButton) {
    let index = sender.tag
    guard !isSearching, index < collectionView.numberOfSections,
          let header = collectionView.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: index)
          ) else {
      return
    }
    let maxOffset = max(0, collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom)
    let offset = min(header.frame.minY - collectionView.adjustedContentInset.top, maxOffset)
    collectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
    highlight(index)
  }

  private func updateSelectedCategory() {
    // Before its first load the grid has no sections, and asking for a header throws.
    guard !isSearching, !sections.isEmpty, collectionView.numberOfSections == sections.count else {
      return
    }
    let probe = collectionView.contentOffset.y + collectionView.adjustedContentInset.top + 1
    var current = 0
    for index in sections.indices {
      guard let header = collectionView.layoutAttributesForSupplementaryElement(
        ofKind: UICollectionView.elementKindSectionHeader,
        at: IndexPath(item: 0, section: index)
      ) else {
        continue
      }
      if header.frame.minY <= probe {
        current = index
      }
    }
    // Scrolled to the bottom: the last section, even when it is too short to reach the top.
    if collectionView.contentOffset.y >= collectionView.contentSize.height - collectionView.bounds.height - 1 {
      current = sections.count - 1
    }
    highlight(current)
  }

  private func highlight(_ index: Int) {
    for (offset, entry) in categoryButtons.enumerated() {
      let selected = offset == index
      entry.button.tintColor = selected ? view.tintColor : .secondaryLabel
      entry.button.accessibilityTraits = selected ? [.button, .selected] : .button
    }
  }

  @objc private func searchChanged() {
    let query = searchField.text ?? ""
    let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
    if searching {
      sections = [(.results, store.search(query, names: names))]
    } else {
      sections = browseSections
    }
    if searching != isSearching {
      isSearching = searching
      collectionView.collectionViewLayout.invalidateLayout()
    }
    categoryBar.alpha = searching ? 0.3 : 1
    categoryBar.isUserInteractionEnabled = !searching
    collectionView.reloadData()
    collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
  }
}

// MARK: - Popover

extension EmojiPickerController: UIPopoverPresentationControllerDelegate {
  /// A popover on iPhone too, instead of the full-screen sheet UIKit adapts it to.
  public func adaptivePresentationStyle(
    for controller: UIPresentationController,
    traitCollection: UITraitCollection
  ) -> UIModalPresentationStyle {
    .none
  }
}

// MARK: - Search field

extension EmojiPickerController: UITextFieldDelegate {
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return false
  }
}

// MARK: - Grid

extension EmojiPickerController: UICollectionViewDataSource, UICollectionViewDelegate {
  public func numberOfSections(in collectionView: UICollectionView) -> Int {
    sections.count
  }

  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    sections[section].items.count
  }

  private func item(at indexPath: IndexPath) -> EmojiItem {
    sections[indexPath.section].items[indexPath.item]
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseIdentifier, for: indexPath)
    if let cell = cell as? EmojiCell {
      let item = item(at: indexPath)
      cell.configure(emoji: store.displayed(item), name: names.names[item.emoji]?.label)
    }
    return cell
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath
  ) -> UICollectionReusableView {
    let header = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind,
      withReuseIdentifier: SectionHeader.reuseIdentifier,
      for: indexPath
    )
    (header as? SectionHeader)?.label.text = title(for: sections[indexPath.section].section)
      .uppercased(with: names.locale)
    return header
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = item(at: indexPath)
    pick(store.displayed(item), base: item.skins != nil ? item.emoji : nil)
  }

  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    updateSelectedCategory()
  }

  @objc fileprivate func longPressed(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began,
          let indexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)),
          let cell = collectionView.cellForItem(at: indexPath) else {
      return
    }
    let item = item(at: indexPath)
    guard let skins = item.skins else {
      return
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    let strip = ToneStripController(emoji: [item.emoji] + skins) { [weak self] emoji in
      self?.pick(emoji, base: item.emoji)
    }
    strip.popoverPresentationController?.sourceView = cell
    strip.popoverPresentationController?.sourceRect = cell.bounds
    strip.popoverPresentationController?.delegate = self
    present(strip, animated: true)
  }
}

// MARK: - Skin tones

/// The base emoji and its five tones in a row, in a popover over the cell long-pressed,
/// like the emoji keyboard's.
private final class ToneStripController: UIViewController {
  private let emoji: [String]
  private let onPick: (String) -> Void

  init(emoji: [String], onPick: @escaping (String) -> Void) {
    self.emoji = emoji
    self.onPick = onPick
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .popover
    popoverPresentationController?.permittedArrowDirections = [.down, .up]
    preferredContentSize = CGSize(width: CGFloat(emoji.count) * 44 + 12, height: 52)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    let row = UIStackView()
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.translatesAutoresizingMaskIntoConstraints = false
    for value in emoji {
      let button = UIButton(type: .system)
      button.setTitle(value, for: .normal)
      button.titleLabel?.font = .systemFont(ofSize: 30)
      button.accessibilityIdentifier = value
      button.addAction(UIAction { [weak self] _ in
        guard let self else { return }
        let onPick = self.onPick
        // Close the strip, then the picker closes itself with the pick.
        self.dismiss(animated: false) { onPick(value) }
      }, for: .touchUpInside)
      row.addArrangedSubview(button)
    }
    view.addSubview(row)
    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 6),
      row.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -6),
      row.topAnchor.constraint(equalTo: guide.topAnchor),
      row.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
  }
}

// MARK: - Cells

private final class EmojiCell: UICollectionViewCell {
  static let reuseIdentifier = "EmojiCell"

  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    label.font = .systemFont(ofSize: 30)
    label.textAlignment = .center
    // Some glyphs (🫡) draw past their advance: a label sized to the text clipped them.
    label.frame = contentView.bounds.insetBy(dx: -4, dy: -4)
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    contentView.addSubview(label)
    let highlight = UIView()
    highlight.backgroundColor = .tertiarySystemFill
    highlight.layer.cornerRadius = 8
    highlight.layer.cornerCurve = .continuous
    selectedBackgroundView = highlight
    isAccessibilityElement = true
    accessibilityTraits = .button
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func configure(emoji: String, name: String?) {
    label.text = emoji
    // The CLDR name, in the picker's language; a bare emoji (a recent with a tone)
    // is read by its system name.
    accessibilityLabel = name ?? emoji
    accessibilityIdentifier = emoji
  }
}

private final class SectionHeader: UICollectionReusableView {
  static let reuseIdentifier = "SectionHeader"

  let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
    ])
    accessibilityTraits = .header
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }
}
