# Runtime locale

## Description

Switches the language of POI names and labels displayed on the map at runtime — no map reload, no republish — using the venue-level locale API: `venue.currentLocale` (the venue's current locale) and `venue.setCurrentLocale(locale)` (changes it). The SDK re-renders labels and its own UI in the new locale itself; there is no manual re-fetch of POI data involved. The set of locales a venue supports is exposed separately as `venue.translator.allLocales`.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
final ValueNotifier<String?> currentLocale = ValueNotifier<String?>(null);

Future<void> getLocales(String requestId) => _call('getLocales', [requestId]);

Future<void> setCurrentLocale(String locale) {
  currentLocale.value = locale;
  return _call('setCurrentLocale', [locale]);
}
```

```js
// window.MapBridge, JS side (assets/www/map.html)
getLocales: function (requestId) {
  if (!venue) {
    sendToNative('localesLoaded', { requestId: requestId, currentLocale: null, allLocales: [] });
    return;
  }
  sendToNative('localesLoaded', {
    requestId: requestId,
    currentLocale: venue.currentLocale,
    allLocales: venue.translator.allLocales,
  });
},

setCurrentLocale: function (locale) {
  if (!venue) return;
  venue.setCurrentLocale(locale).catch(function (error) {
    console.error('[MapBridge] setCurrentLocale failed:', error);
  });
},
```

The relevant `Venue`/`Translator` surface (`visioone/src/VisioOne/Venue/Venue.ts`, `visioone/src/VisioOne/Content/Translator.ts`):

```ts
interface Venue {
  /**
   * The current locale used by this Venue.
   * Labels will be displayed with "text" field corresponding to their POI's LocaleEntry
   * when it exists, otherwise the Label "text" will be empty.
   * When a View exists, each UI items (and the current Navigation) will use this locale to be displayed.
   */
  readonly currentLocale: string;

  /**
   * Modifies the current locale.
   * Available locales can be retrieved from Translator.allLocales
   * @param locale the new current locale.
   */
  setCurrentLocale(locale: string): Promise<void>;

  readonly translator: Translator;
}

interface Translator {
  /** The list of all locales existing for this venue. */
  readonly allLocales: string[];
}
```

`getLocales` is a request/response round trip (same `requestId`-correlated pattern as `category-highlight`'s `getCategories` / `categoriesLoaded`): the Native → JS call is fire-and-forget, and the JS side reports back asynchronously with a `localesLoaded` message carrying the same `requestId`, the venue's `currentLocale`, and its full `allLocales` list. `setCurrentLocale` is a plain fire-and-forget one-way call — no response message is needed, since the effect (POI/label text changing) is directly observable on the map once the underlying `Promise` resolves.

The demo's `RuntimeLocaleOverlay` (`lib/features/runtime_locale_overlay.dart`) calls `getLocales` once when it mounts, to read the venue's current locale and preselect the matching chip, then calls `setCurrentLocale` on tap. `VisioOneController.currentLocale` is a `ValueNotifier<String?>` held on the controller (not the overlay), for the same reason as `highlightedCategoryId` (see `docs/features/category-highlight.md`): it must survive the bottom sheet being closed and reopened.

## Things to know

- **`setCurrentLocale` returns a `Promise<void>` (a `Future<void>` on the Dart side).** It is asynchronous — nothing in the TSDoc guarantees the map has finished re-rendering by the time the call returns, only that it *will* re-render. The demo does not await it before reflecting the new selection in the UI (`currentLocale.value` is set optimistically, before the underlying JS call is even issued) since the visual result is what actually confirms the change, not the resolved `Promise`.
- **`'default'` can be a byte-identical duplicate of another locale.** On the shared demo map used by this repo (`kDefaultMapHash`), `venue.translator.allLocales` returns `['default', 'en', 'fr']`, but `'default'` was confirmed (byte-for-byte diff of the published map payload) to carry the exact same French content as `'fr'` — not a distinct third language. This is a data/publishing quirk of that particular map, not a general SDK guarantee that `'default'` is ever redundant; an integrator working against their own map should check `allLocales` and the actual translated content rather than assume the same holds. This demo does not offer `'default'` as a selectable option for that reason — only `'en'`/`'fr'` are exposed, and a `currentLocale` of `'default'` is treated as equivalent to `'fr'` purely for the purpose of showing which chip is active.
- **No manual re-fetch needed.** Per `Venue.currentLocale`'s TSDoc, once `setCurrentLocale` resolves, POI labels re-render using the `POILocaleEntry` for the new locale (empty text if none exists for a given POI/locale pair), and any current View UI — including an in-progress Navigation — follows the same locale. There is no separate "refresh POIs" or "refresh UI" call to make afterward.
- **A POI can be locale-less.** If a POI has no `LocaleEntry` for the newly selected locale, its label text renders empty rather than falling back to another locale — worth knowing before assuming every POI name will always show something after a locale switch.

## Learn more

See `docs/features/category-highlight.md` for the sibling `requestId`-correlated bridge request/response idiom (`getCategories` / `categoriesLoaded`) that `getLocales` / `localesLoaded` follows here.
