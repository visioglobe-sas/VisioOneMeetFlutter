// Values of Visioglobe's shared demo map: replace them with your own map's hash and POI ids.
//
// Every feature screen of this demo opens with its fields prefilled from
// this file, so a visitor can press the action button right away. Default
// *texts* shown in fields (label / badge text) are localized and live in
// `lib/l10n/app_*.arb` instead (keys `dynamicPoiDefaultLabelText`, `textLabelDefaultText`, `htmlBadgeDefaultText`).

/// Demo map hash (41 characters), the same map as the other VisioOneMeet
/// demo repos. See docs/INTEGRATION_GUIDE.md, part D, to get YOUR map's hash
/// from my.visioglobe.com.
const String kDefaultMapHash = 'kbae8e6c066cca4b02c2afac2bc963a643d87437a';

/// Map dedicated to the `custom-data` demo (see `docs/features/custom-data.md`):
/// the shared demo map above has no published `CustomData`, so
/// `venue.refreshCustomData()` rejects there (404 on `customData.json`) and
/// `venue.getPOICustomData(poi)` always returns `{}`. Only used by
/// `Feature.customData` (see `lib/features/feature_screen.dart`).
const String kCustomDataMapHash = 'kd9426d8cb3f1c532f22b5bcbd325c280bd351feb';

/// POI / place ids of the shared demo map ([kDefaultMapHash]) used as field
/// defaults, unless noted otherwise. Each id has been checked to exist with a
/// surface, and each From/To pair to return a route.
abstract final class DemoMap {
  /// goto-poi: place the camera goes to.
  static const String gotoPoiId = 'B3-UL00-ID0076';

  /// occupancy-simulated: place whose occupancy is simulated.
  static const String occupancyPlaceId = 'B3-UL00-ID0065';

  /// clickable-surface: place whose surface is made clickable.
  static const String clickableSurfacePlaceId = 'B3-UL00-ID0064';

  /// compute-navigation and custom-navigation-trace: route From / To.
  static const String itineraryFrom = 'B4-UL00-ID0009';
  static const String itineraryTo = 'B3-UL00-ID0064';

  /// navigation-exclude-modalities: route From / To (the default route uses
  /// an elevator, so "Avoid elevator" visibly changes it).
  static const String excludeModalitiesFrom = 'B1-LL01-ID0013';
  static const String excludeModalitiesTo = 'B1-UL02-ID0012';

  /// accessible-mode: route From / To (changes floor, so the accessible
  /// route differs from the default one).
  static const String accessibleFrom = 'B4-UL00-ID0010';
  static const String accessibleTo = 'B4-UL01-ID0014';

  /// simulated-position, camera-lock-on-position, geofencing,
  /// accuracy-circle-style: the simulated position goes back and forth
  /// between these two POIs.
  static const String trackingFrom = 'B4-UL00-ID0009';
  static const String trackingTo = 'B4-UL00-ID0010';

  /// geofencing: POI whose first surface is the watched zone.
  static const String geofenceZoneId = 'B4-UL00-ID0010';

  /// custom-data: place id on [kCustomDataMapHash] (not the shared map),
  /// plus the quick-select chips, all with published `CustomData`.
  static const String customDataPlaceId = 'B3-UL00-ID0065';
  static const List<String> customDataQuickIds = ['B1', 'B3-UL00-ID0065', 'B3-UL00-ID0064'];

  /// dynamic-poi-crud: id given to the POI created at runtime.
  static const String dynamicPoiNewId = 'demo-poi';

  /// dynamic-poi-crud, 3d-icon-marker, custom-text-label,
  /// html-overlay-marker: existing POI the created element is anchored to.
  static const String anchorPoiId = 'B4-UL00-ID0009';

  /// camera-showcase-carousel: POIs the camera tours, in order.
  static const List<String> carouselStopIds = ['B4-UL00-ID0009', 'B1-LL01-ID0152', 'B3-UL00-ID0064', 'B4-UL03-ID0015'];
}
