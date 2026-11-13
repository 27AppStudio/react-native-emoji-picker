// Builds the iOS picker's emoji data from emojibase-data (Unicode emoji + CLDR names).
//
//   yarn gen:emoji
//
// Writes ios/Resources/emoji.json (the grid: groups, emoji, skin tones, Unicode
// version) and ios/Resources/names-<locale>.json (localized group titles and the
// words search matches). Re-run after bumping emojibase-data for a new Unicode
// release; the picker hides whatever the device can't draw at runtime, so no
// version table needs updating. Android uses Google's EmojiPickerView and needs none of this.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

// Run from the repository root (`yarn gen:emoji`).
const root = process.cwd();
const require = createRequire(join(root, 'package.json'));
const out = join(root, 'ios', 'Resources');
const dataDir = dirname(require.resolve('emojibase-data/package.json'));

// Each locale adds ~150 KB to the app. Base languages only: regional variants
// (en-gb, es-mx, zh-hant) fall back to these.
const LOCALES = ['en', 'fr', 'es', 'de', 'it', 'pt', 'nl', 'ja', 'ko', 'zh'];

// Emojibase has no messages for the recents section and the search field.
const RECENTS = {
  en: 'Frequently Used',
  fr: 'Fréquemment utilisés',
  es: 'Usados con frecuencia',
  de: 'Häufig benutzt',
  it: 'Usati di frequente',
  pt: 'Usados com frequência',
  nl: 'Veelgebruikt',
  ja: 'よく使う項目',
  ko: '자주 사용하는 항목',
  zh: '常用',
};

const SEARCH = {
  en: 'Search',
  fr: 'Rechercher',
  es: 'Buscar',
  de: 'Suchen',
  it: 'Cerca',
  pt: 'Pesquisar',
  nl: 'Zoek',
  ja: '検索',
  ko: '검색',
  zh: '搜索',
};

const COMPONENT_GROUP = 2; // skin tone and hair swatches, not pickable on their own

const read = (path) => JSON.parse(readFileSync(join(dataDir, path), 'utf8'));
const groupKeys = read('meta/groups.json').groups;

/** The five single-tone variants; multi-person emoji keep the ones where everyone shares a tone. */
function skinTones(skins) {
  if (!skins) return undefined;
  const byTone = new Map();
  for (const skin of skins) {
    const tones = Array.isArray(skin.tone) ? skin.tone : [skin.tone];
    if (tones.every((tone) => tone === tones[0]) && !byTone.has(tones[0])) {
      byTone.set(tones[0], skin.emoji);
    }
  }
  const variants = [1, 2, 3, 4, 5].map((tone) => byTone.get(tone));
  return variants.every(Boolean) ? variants : undefined;
}

const english = read('en/data.json');
const groups = [];
for (const emoji of english) {
  if (emoji.group == null || emoji.group === COMPONENT_GROUP) continue;
  let group = groups.find((g) => g.id === emoji.group);
  if (!group) {
    group = { id: emoji.group, key: groupKeys[emoji.group], emoji: [] };
    groups.push(group);
  }
  group.emoji.push({
    emoji: emoji.emoji,
    order: emoji.order,
    version: emoji.version,
    skins: skinTones(emoji.skins),
  });
}
groups.sort((a, b) => a.id - b.id);

const grid = groups.map((group) => ({
  key: group.key,
  emoji: group.emoji
    .sort((a, b) => a.order - b.order)
    .map(({ emoji, version, skins }) =>
      skins ? { e: emoji, v: version, s: skins } : { e: emoji, v: version }
    ),
}));
const pickable = new Set(grid.flatMap((group) => group.emoji.map((e) => e.e)));

mkdirSync(out, { recursive: true });
writeFileSync(join(out, 'emoji.json'), JSON.stringify(grid));

for (const locale of LOCALES) {
  const messages = read(`${locale}/messages.json`);
  const names = {};
  for (const emoji of read(`${locale}/compact.json`)) {
    if (!pickable.has(emoji.unicode)) continue;
    // Search matches the start of any word, so the label and the tags go in one string.
    const words = [emoji.label, ...(emoji.tags || [])]
      .join(' ')
      .toLocaleLowerCase(locale);
    names[emoji.unicode] = [emoji.label, words];
  }
  const groupTitles = Object.fromEntries(
    messages.groups.map((g) => [g.key, g.message])
  );
  writeFileSync(
    join(out, `names-${locale}.json`),
    JSON.stringify({
      recents: RECENTS[locale],
      search: SEARCH[locale],
      groups: groupTitles,
      names,
    })
  );
}

const count = grid.reduce((n, g) => n + g.emoji.length, 0);
console.log(
  `${count} emoji in ${grid.length} groups, ${LOCALES.length} locales → ${out}`
);
