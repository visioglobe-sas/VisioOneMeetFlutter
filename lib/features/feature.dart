import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/feature_session.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import '3d-icon-marker/icon_marker_overlay.dart';
import 'accessible-mode/accessible_mode_overlay.dart';
import 'accuracy-circle-style/accuracy_circle_style_overlay.dart';
import 'add-locale/add_locale_overlay.dart';
import 'auth-token/auth_token_screen.dart';
import 'camera-lock-on-position/camera_lock_on_position_overlay.dart';
import 'camera-projection-toggle/camera_projection_session.dart';
import 'camera-projection-toggle/camera_projection_toggle_overlay.dart';
import 'camera-showcase-carousel/camera_carousel_session.dart';
import 'camera-showcase-carousel/camera_showcase_carousel_overlay.dart';
import 'category-highlight/category_highlight_overlay.dart';
import 'clickable-surface/clickable_surface_overlay.dart';
import 'compute-navigation/compute_navigation_overlay.dart';
import 'custom-base-url/custom_base_url_screen.dart';
import 'custom-data/custom_data_overlay.dart';
import 'custom-navigation-trace/custom_navigation_trace_overlay.dart';
import 'custom-text-label/custom_text_label_overlay.dart';
import 'custom-theme/custom_theme_overlay.dart';
import 'dynamic-poi-crud/dynamic_poi_crud_overlay.dart';
import 'explore-mode/explore_mode_overlay.dart';
import 'floor-selector/floor_selector_overlay.dart';
import 'geofencing/geofencing_overlay.dart';
import 'goto-poi/goto_poi_overlay.dart';
import 'html-overlay-marker/html_overlay_marker_overlay.dart';
import 'html-overlay-marker/html_overlay_marker_session.dart';
import 'native-ui-replacement/native_ui_replacement_overlay.dart';
import 'navigation-exclude-modalities/navigation_exclude_modalities_overlay.dart';
import 'occupancy-simulated/occupancy_simulation_overlay.dart';
import 'occupancy-simulated/occupancy_simulation_session.dart';
import 'poi-click/poi_click_overlay.dart';
import 'reset-view/reset_view_overlay.dart';
import 'runtime-locale/runtime_locale_overlay.dart';
import 'simulated-position/simulated_position_overlay.dart';
import 'simulated-position/simulated_position_session.dart';
import 'ui-part-visibility/ui_part_visibility_overlay.dart';

typedef FeatureWidgetBuilder = Widget Function(BuildContext context, VisioOneController controller);

/// Tout ce que l'app sait d'une feature, en un seul endroit : le menu
/// (`FeatureMenuScreen`) et l'écran (`FeatureScreen`) ne lisent que ça.
///
/// Le code de la feature elle-même vit dans `lib/features/<slug>/` (panneau,
/// commandes du pont, session éventuelle) et `assets/www/features/<slug>.js`
/// (appels SDK) ; sa doc dans `docs/features/<slug>.md`.
class FeatureSpec {
  const FeatureSpec({
    required this.slug,
    required this.title,
    required this.description,
    this.panel,
    this.mapOverlay,
    this.mapHash = kDefaultMapHash,
    this.viewOptions,
    this.createSession,
    this.onMapMessage,
    this.screen,
  }) : assert((panel == null) != (screen == null), 'panel ou screen, exactement un des deux');

  /// Identifiant kebab-case, identique au dossier `lib/features/<slug>/`, au
  /// script `assets/www/features/<slug>.js` et à la doc `docs/features/<slug>.md`.
  final String slug;

  /// Titre et description du menu, traduits (`lib/l10n/app_*.arb`).
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) description;

  /// Contenu du bottom sheet ouvert par le FAB, reconstruit à chaque
  /// ouverture (l'état durable vit dans `controller.panel` ou la session).
  final FeatureWidgetBuilder? panel;

  /// Widget affiché directement sur la carte une fois prête (pas dans le
  /// bottom sheet), ou `null` s'il n'y en a pas.
  final FeatureWidgetBuilder? mapOverlay;

  /// Carte chargée pour cet écran.
  final String mapHash;

  /// 3e argument de `createView` (`null` = aucune option).
  final Map<String, Object>? viewOptions;

  /// Crée la [FeatureSession] de l'écran (boucle, minuteur, miroir d'état
  /// SDK), juste après son `VisioOneController`, avant le chargement de la
  /// carte ; libérée en quittant l'écran.
  final FeatureSession Function(VisioOneController controller)? createSession;

  /// Réagit aux messages JS -> Native que `VisioOneMapShell` ne gère pas
  /// lui-même, même panneau fermé (ex. `poiSelected` pour `poi-click`).
  final void Function(BuildContext context, VisioOneMessage message)? onMapMessage;

  /// Écran complet remplaçant l'écran carte standard, pour les features
  /// qui n'entrent pas dans ce moule : `custom-base-url` (recharge toute la
  /// carte avec une autre `baseURL`) et `auth-token` (exemple de code, sans
  /// carte).
  final Widget Function(BuildContext context, FeatureSpec feature)? screen;
}

/// Catalogue des features démontrées, dans l'ordre du menu.
final List<FeatureSpec> kFeatures = [
  FeatureSpec(
    slug: 'reset-view',
    title: (l10n) => l10n.resetViewTitle,
    description: (l10n) => l10n.resetViewDescription,
    panel: (context, controller) => ResetViewOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'occupancy-simulated',
    title: (l10n) => l10n.occupancySimulatedTitle,
    description: (l10n) => l10n.occupancySimulatedDescription,
    panel: (context, controller) => OccupancySimulationOverlay(controller: controller),
    createSession: OccupancySimulationSession.new,
  ),
  FeatureSpec(
    slug: 'poi-click',
    title: (l10n) => l10n.poiClickTitle,
    description: (l10n) => l10n.poiClickDescription,
    panel: (context, controller) => const PoiClickOverlay(),
    onMapMessage: handlePoiSelectedMessage,
  ),
  FeatureSpec(
    slug: 'goto-poi',
    title: (l10n) => l10n.gotoPoiTitle,
    description: (l10n) => l10n.gotoPoiDescription,
    panel: (context, controller) => GotoPoiOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'floor-selector',
    title: (l10n) => l10n.floorSelectorTitle,
    description: (l10n) => l10n.floorSelectorDescription,
    panel: (context, controller) => FloorSelectorOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'compute-navigation',
    title: (l10n) => l10n.computeNavigationTitle,
    description: (l10n) => l10n.computeNavigationDescription,
    panel: (context, controller) => ComputeNavigationOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'ui-part-visibility',
    title: (l10n) => l10n.uiPartVisibilityTitle,
    description: (l10n) => l10n.uiPartVisibilityDescription,
    panel: (context, controller) => UiPartVisibilityOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'simulated-position',
    title: (l10n) => l10n.simulatedPositionTitle,
    description: (l10n) => l10n.simulatedPositionDescription,
    panel: (context, controller) => SimulatedPositionOverlay(
      controller: controller,
      initialOriginId: DemoMap.trackingFrom,
      initialDestinationId: DemoMap.trackingTo,
    ),
    createSession: SimulatedPositionSession.new,
  ),
  FeatureSpec(
    slug: 'camera-lock-on-position',
    title: (l10n) => l10n.cameraLockOnPositionTitle,
    description: (l10n) => l10n.cameraLockOnPositionDescription,
    panel: (context, controller) => CameraLockOnPositionOverlay(controller: controller),
    createSession: SimulatedPositionSession.new,
  ),
  FeatureSpec(
    slug: 'clickable-surface',
    title: (l10n) => l10n.clickableSurfaceTitle,
    description: (l10n) => l10n.clickableSurfaceDescription,
    panel: (context, controller) => ClickableSurfaceOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'custom-data',
    title: (l10n) => l10n.customDataTitle,
    description: (l10n) => l10n.customDataDescription,
    panel: (context, controller) => CustomDataOverlay(controller: controller),
    // La carte de démo partagée n'a aucune `CustomData` publiée (voir
    // `docs/features/custom-data.md`).
    mapHash: kCustomDataMapHash,
  ),
  FeatureSpec(
    slug: 'category-highlight',
    title: (l10n) => l10n.categoryHighlightTitle,
    description: (l10n) => l10n.categoryHighlightDescription,
    panel: (context, controller) => CategoryHighlightOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'dynamic-poi-crud',
    title: (l10n) => l10n.dynamicPoiCrudTitle,
    description: (l10n) => l10n.dynamicPoiCrudDescription,
    panel: (context, controller) => DynamicPoiCrudOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'runtime-locale',
    title: (l10n) => l10n.runtimeLocaleTitle,
    description: (l10n) => l10n.runtimeLocaleDescription,
    panel: (context, controller) => RuntimeLocaleOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'native-ui-replacement',
    title: (l10n) => l10n.nativeUiReplacementTitle,
    description: (l10n) => l10n.nativeUiReplacementDescription,
    panel: (context, controller) => NativeUiReplacementOverlay(controller: controller),
    // Le sélecteur d'étage natif doit être visible dès l'arrivée sur
    // l'écran, sans ouvrir le FAB.
    mapOverlay: (context, controller) => NativeUiReplacementMapPanel(controller: controller),
  ),
  FeatureSpec(
    slug: 'explore-mode',
    title: (l10n) => l10n.exploreModeTitle,
    description: (l10n) => l10n.exploreModeDescription,
    panel: (context, controller) => ExploreModeOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'add-locale',
    title: (l10n) => l10n.addLocaleTitle,
    description: (l10n) => l10n.addLocaleDescription,
    panel: (context, controller) => AddLocaleOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'geofencing',
    title: (l10n) => l10n.geofencingTitle,
    description: (l10n) => l10n.geofencingDescription,
    panel: (context, controller) => GeofencingOverlay(controller: controller),
    createSession: SimulatedPositionSession.new,
  ),
  FeatureSpec(
    slug: 'custom-base-url',
    title: (l10n) => l10n.customBaseUrlTitle,
    description: (l10n) => l10n.customBaseUrlDescription,
    screen: (context, feature) => CustomBaseUrlScreen(feature: feature),
  ),
  FeatureSpec(
    slug: 'custom-navigation-trace',
    title: (l10n) => l10n.customNavigationTraceTitle,
    description: (l10n) => l10n.customNavigationTraceDescription,
    panel: (context, controller) => CustomNavigationTraceOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'navigation-exclude-modalities',
    title: (l10n) => l10n.navigationExcludeModalitiesTitle,
    description: (l10n) => l10n.navigationExcludeModalitiesDescription,
    panel: (context, controller) => NavigationExcludeModalitiesOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'accessible-mode',
    title: (l10n) => l10n.accessibleModeTitle,
    description: (l10n) => l10n.accessibleModeDescription,
    panel: (context, controller) => AccessibleModeOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: '3d-icon-marker',
    title: (l10n) => l10n.iconMarkerTitle,
    description: (l10n) => l10n.iconMarkerDescription,
    panel: (context, controller) => IconMarkerOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'custom-text-label',
    title: (l10n) => l10n.customTextLabelTitle,
    description: (l10n) => l10n.customTextLabelDescription,
    panel: (context, controller) => CustomTextLabelOverlay(controller: controller),
  ),
  FeatureSpec(
    slug: 'html-overlay-marker',
    title: (l10n) => l10n.htmlOverlayMarkerTitle,
    description: (l10n) => l10n.htmlOverlayMarkerDescription,
    panel: (context, controller) => HtmlOverlayMarkerOverlay(controller: controller),
    createSession: HtmlOverlayMarkerSession.new,
  ),
  FeatureSpec(
    slug: 'custom-theme',
    title: (l10n) => l10n.customThemeTitle,
    description: (l10n) => l10n.customThemeDescription,
    panel: (context, controller) => CustomThemeOverlay(controller: controller),
    // Sans `enableShadows`, `view.setTheme` n'a aucun effet visible (voir
    // `docs/features/custom-theme.md`).
    viewOptions: const {'enableShadows': true},
  ),
  FeatureSpec(
    slug: 'accuracy-circle-style',
    title: (l10n) => l10n.accuracyCircleStyleTitle,
    description: (l10n) => l10n.accuracyCircleStyleDescription,
    panel: (context, controller) => AccuracyCircleStyleOverlay(controller: controller),
    createSession: SimulatedPositionSession.new,
  ),
  FeatureSpec(
    slug: 'camera-projection-toggle',
    title: (l10n) => l10n.cameraProjectionTitle,
    description: (l10n) => l10n.cameraProjectionDescription,
    panel: (context, controller) => CameraProjectionToggleOverlay(controller: controller),
    createSession: CameraProjectionSession.new,
  ),
  FeatureSpec(
    slug: 'camera-showcase-carousel',
    title: (l10n) => l10n.cameraShowcaseCarouselTitle,
    description: (l10n) => l10n.cameraShowcaseCarouselDescription,
    panel: (context, controller) => CameraShowcaseCarouselOverlay(controller: controller),
    createSession: CameraCarouselSession.new,
  ),
  FeatureSpec(
    slug: 'auth-token',
    title: (l10n) => l10n.authTokenTitle,
    description: (l10n) => l10n.authTokenDescription,
    // Exemple de code uniquement, aucune carte protégée à charger : page de
    // texte (voir `auth-token/auth_token_sample.dart`).
    screen: (context, feature) => AuthTokenScreen(title: feature.title(AppLocalizations.of(context)!)),
  ),
];
