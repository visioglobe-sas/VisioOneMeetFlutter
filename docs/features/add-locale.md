# Add locale

## Description

Adds a brand-new locale, `'es'` (Spanish), to the SDK at runtime — one that was never authored in VisioMapEditor for this map — using the translator-level API: `venue.translator.addLocale(locale, resources)` registers a fixed key/value dictionary under `'es'`, and `venue.translator.translate(key, locale)` reads a value back to prove the round trip worked. The demo adds two kinds of keys: one predefined SDK key (`'search-for-anything'`, one of the built-in UI strings listed in `addLocale`'s own TSDoc) to show this can override the SDK's own built-in text, and one custom, app-defined key (`'welcome-message'`, which has no meaning to the SDK itself) to show this is a general-purpose i18n store the app can also use for its own strings.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
final ValueNotifier<Map<String, String>?> spanishLocaleTranslations =
    ValueNotifier<Map<String, String>?>(null);

Future<void> addSpanishLocale(String requestId, Map<String, String> resources) =>
    _call('addSpanishLocale', [requestId, resources]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
addSpanishLocale: function (requestId, resources) {
  if (!venue) {
    sendToNative('spanishLocaleAdded', { requestId: requestId, values: {} });
    return;
  }
  venue.translator.addLocale('es', resources);
  var values = {};
  Object.keys(resources).forEach(function (key) {
    values[key] = venue.translator.translate(key, 'es');
  });
  sendToNative('spanishLocaleAdded', { requestId: requestId, values: values });
},
```

The relevant `Translator` surface (`visioone/src/VisioOne/Content/Translator.ts`):

```ts
interface Translator {
  /** The list of all locales existing for this venue. */
  readonly allLocales: string[];

  /**
   * Create a locale at runtime. It will not be saved once the application is reloaded.
   * @param locale the locale to create.
   * @param resources the locale entry — a map of key/value. Internally VisioOne relies on
   * i18next, and "resources" must conform to the "resources" parameter used by that library.
   */
  addLocale(locale: string, resources: Resources): void;

  /**
   * Translate given key to given locale.
   * @param key key of the translation you look for.
   * @param locale locale in which you want to translate.
   * @param context optional i18next-style context for translation variants.
   */
  translate(key: string, locale: string, context?: Context): string;

  /** Remove a locale for the available locales. */
  removeLocale(locale: string): void;

  /** Retrieve the translation resources for a specific locale. */
  getLocale(locale: string): Resources;
}

interface Resources {
  readonly [key: string]: string;
}
```

The demo's `AddLocaleOverlay` (`lib/features/add_locale_overlay.dart`) calls `addSpanishLocale` once, on tap of "Add Spanish locale", with a fixed two-entry dictionary (`kSpanishResources`): `'search-for-anything'` (a predefined SDK UI key) and `'welcome-message'` (a custom app key). `addLocale` and the `translate` readback for both keys are chained in the same JS handler — one bridge round trip, the same idiom `loadCustomData` already uses to chain `refreshCustomData`/`getPOICustomData` (see `docs/features/custom-data.md`) — rather than two separate native calls. The response (`spanishLocaleAdded`, correlated by `requestId`) carries the translated value for each key; the panel displays each one next to its key, replacing a "(not added yet)" placeholder shown before the button is pressed. A second, optional button, "Switch to Spanish", reuses `venue.setCurrentLocale('es')` (the exact same call `runtime-locale` uses — see `docs/features/runtime-locale.md`) to make the newly-added locale "live", in case any of the SDK's own default UI parts happen to be visible on screen.

`VisioOneController.spanishLocaleTranslations` is a `ValueNotifier<Map<String, String>?>` held on the controller rather than the overlay, for the same reason as `currentLocale`/`highlightedCategoryId` (see `docs/features/runtime-locale.md`/`docs/features/category-highlight.md`): `addLocale` has already taken effect on the SDK side the first time it runs, so reopening the bottom sheet must keep showing the "added" state instead of resetting to "(not added yet)".

## Things to know

- **`addLocale` never touches POI/label/floor/building names.** It is backed entirely by a generic i18next resource bundle, completely separate from the venue's own POI/floor/building/category translation data — which is parsed once, at load, from the published map's own JSON, and is exposed only through `translatePOI`/`translateFloor`/`translateBuilding`/`translateCategory`. No matter what key you add through `addLocale`, it can never change what a POI or label is *named* on the map itself. It only affects (a) the SDK's own predefined UI/navigation strings, if you happen to add one of the keys listed in `addLocale`'s TSDoc (e.g. `'search-for-anything'`, `'go'`, `'cancel'`, `'turnRight'`, `'changeFloor'`, …), and (b) any arbitrary custom key your own app defines and later reads back via `translate`.
- **`translate`/`addLocale` are synchronous, not `Promise`-based.** Unlike `setCurrentLocale`, both return their value/complete immediately — there is no asynchronous wait involved on the SDK side. The demo still routes the call through the native ↔ JS bridge asynchronously (as every bridge command here does), but that's an artifact of the bridge, not of the SDK API itself.
- **`translate` is the reliable proof, independent of visible UI.** Reading a value back with `venue.translator.translate(key, 'es')` right after `addLocale` confirms the round trip worked regardless of whether any of the SDK's own default UI parts are on screen — which is why this demo always displays the readback, and treats "Switch to Spanish" (`setCurrentLocale('es')`) as a bonus, not the primary proof.
- **This complements, but is distinct from, `runtime-locale`.** `runtime-locale` (`venue.setCurrentLocale`) switches between locales already authored for this map's own POI/label data (`'en'`/`'fr'` on the shared demo map). `add-locale` demonstrates the opposite direction: registering a locale that was *never* authored anywhere for this map, and that can only ever affect the SDK's own UI/nav strings and custom app keys — never the map's own POI/label content. See `docs/features/runtime-locale.md`.

## Learn more

- `docs/features/runtime-locale.md` — the sibling feature this one complements (switching between already-authored locales vs. adding a brand-new one).
- The same `Translator` interface also exposes `removeLocale(locale)` (undoes `addLocale`) and `getLocale(locale)` (reads back the full resource map for a locale) — not built into this demo's UI, but available on the same object for an integrator who needs them.
