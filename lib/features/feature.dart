import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'add_locale_overlay.dart';
import 'camera_lock_on_position_overlay.dart';
import 'category_highlight_overlay.dart';
import 'clickable_surface_overlay.dart';
import 'compute_navigation_overlay.dart';
import 'custom_data_overlay.dart';
import 'dynamic_poi_crud_overlay.dart';
import 'explore_mode_overlay.dart';
import 'floor_selector_overlay.dart';
import 'goto_poi_overlay.dart';
import 'native_ui_replacement_overlay.dart';
import 'occupancy_simulation_overlay.dart';
import 'poi_click_overlay.dart';
import 'reset_view_overlay.dart';
import 'runtime_locale_overlay.dart';
import 'simulated_position_overlay.dart';
import 'ui_part_visibility_overlay.dart';

/// Catalogue des features démontrées par l'app — source unique de vérité
/// pour la liste du menu et la résolution de l'overlay associé.
///
/// `slug` correspond au nom de branche/doc partagé entre le hub
/// (`VisioOneHub/CHECKLIST.md`) et les 5 dépôts plateforme, ex. `reset-view`.
enum Feature {
  resetView('reset-view'),
  occupancySimulated('occupancy-simulated'),
  poiClick('poi-click'),
  gotoPoi('goto-poi'),
  floorSelector('floor-selector'),
  computeNavigation('compute-navigation'),
  uiPartVisibility('ui-part-visibility'),
  simulatedPosition('simulated-position'),
  cameraLockOnPosition('camera-lock-on-position'),
  clickableSurface('clickable-surface'),
  customData('custom-data'),
  categoryHighlight('category-highlight'),
  dynamicPoiCrud('dynamic-poi-crud'),
  runtimeLocale('runtime-locale'),
  nativeUiReplacement('native-ui-replacement'),
  exploreMode('explore-mode'),
  addLocale('add-locale');

  const Feature(this.slug);

  final String slug;

  String title(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewTitle,
    Feature.occupancySimulated => l10n.occupancySimulatedTitle,
    Feature.poiClick => l10n.poiClickTitle,
    Feature.gotoPoi => l10n.gotoPoiTitle,
    Feature.floorSelector => l10n.floorSelectorTitle,
    Feature.computeNavigation => l10n.computeNavigationTitle,
    Feature.uiPartVisibility => l10n.uiPartVisibilityTitle,
    Feature.simulatedPosition => l10n.simulatedPositionTitle,
    Feature.cameraLockOnPosition => l10n.cameraLockOnPositionTitle,
    Feature.clickableSurface => l10n.clickableSurfaceTitle,
    Feature.customData => l10n.customDataTitle,
    Feature.categoryHighlight => l10n.categoryHighlightTitle,
    Feature.dynamicPoiCrud => l10n.dynamicPoiCrudTitle,
    Feature.runtimeLocale => l10n.runtimeLocaleTitle,
    Feature.nativeUiReplacement => l10n.nativeUiReplacementTitle,
    Feature.exploreMode => l10n.exploreModeTitle,
    Feature.addLocale => l10n.addLocaleTitle,
  };

  String description(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewDescription,
    Feature.occupancySimulated => l10n.occupancySimulatedDescription,
    Feature.poiClick => l10n.poiClickDescription,
    Feature.gotoPoi => l10n.gotoPoiDescription,
    Feature.floorSelector => l10n.floorSelectorDescription,
    Feature.computeNavigation => l10n.computeNavigationDescription,
    Feature.uiPartVisibility => l10n.uiPartVisibilityDescription,
    Feature.simulatedPosition => l10n.simulatedPositionDescription,
    Feature.cameraLockOnPosition => l10n.cameraLockOnPositionDescription,
    Feature.clickableSurface => l10n.clickableSurfaceDescription,
    Feature.customData => l10n.customDataDescription,
    Feature.categoryHighlight => l10n.categoryHighlightDescription,
    Feature.dynamicPoiCrud => l10n.dynamicPoiCrudDescription,
    Feature.runtimeLocale => l10n.runtimeLocaleDescription,
    Feature.nativeUiReplacement => l10n.nativeUiReplacementDescription,
    Feature.exploreMode => l10n.exploreModeDescription,
    Feature.addLocale => l10n.addLocaleDescription,
  };

  Widget buildOverlay(BuildContext context, VisioOneController controller) => switch (this) {
    Feature.resetView => ResetViewOverlay(controller: controller),
    Feature.occupancySimulated => OccupancySimulationOverlay(controller: controller),
    Feature.poiClick => const PoiClickOverlay(),
    Feature.gotoPoi => GotoPoiOverlay(controller: controller),
    Feature.floorSelector => FloorSelectorOverlay(controller: controller),
    Feature.computeNavigation => ComputeNavigationOverlay(controller: controller),
    Feature.uiPartVisibility => UiPartVisibilityOverlay(controller: controller),
    Feature.simulatedPosition => SimulatedPositionOverlay(controller: controller),
    Feature.cameraLockOnPosition => CameraLockOnPositionOverlay(controller: controller),
    Feature.clickableSurface => ClickableSurfaceOverlay(controller: controller),
    Feature.customData => CustomDataOverlay(controller: controller),
    Feature.categoryHighlight => CategoryHighlightOverlay(controller: controller),
    Feature.dynamicPoiCrud => DynamicPoiCrudOverlay(controller: controller),
    Feature.runtimeLocale => RuntimeLocaleOverlay(controller: controller),
    Feature.nativeUiReplacement => NativeUiReplacementOverlay(controller: controller),
    Feature.exploreMode => ExploreModeOverlay(controller: controller),
    Feature.addLocale => AddLocaleOverlay(controller: controller),
  };

  /// Overlay affiché directement sur la carte (pas dans le bottom sheet du
  /// FAB), pour les rares features qui en ont besoin — seule
  /// `native-ui-replacement` aujourd'hui : son panneau de sélection d'étage
  /// natif doit être visible dès l'arrivée sur l'écran, sans que le visiteur
  /// n'ait à ouvrir le FAB pour le découvrir (voir
  /// [NativeUiReplacementMapPanel]). `null` pour toutes les autres features.
  Widget? buildMapOverlay(BuildContext context, VisioOneController controller) => switch (this) {
    Feature.nativeUiReplacement => NativeUiReplacementMapPanel(controller: controller),
    _ => null,
  };

  /// Réagit à un message JS -> Native que [VisioOneMapShell] ne gère pas
  /// lui-même (voir son `onMessage`). Seule `poi-click` s'en sert pour
  /// l'instant (`poiSelected` -> panneau d'info du POI tapé) ; les autres
  /// features n'ont rien à faire ici, tant que `map.html` ne diffuse ces
  /// événements que sur `view` (donc identiquement sur tous les écrans).
  ///
  /// `floor-selector` n'en a pas besoin non plus : son overlay écoute
  /// directement `controller.messages` (`venueLayout`, `floorChanged`) tant
  /// qu'il est monté dans le bottom sheet, plutôt que de passer par ce
  /// routage — voir [FloorSelectorOverlay]. `simulated-position` fait de même
  /// pour `poiPositionResolved`, voir [SimulatedPositionOverlay].
  /// `camera-lock-on-position` réutilise directement [SimulatedPositionOverlay]
  /// pour cette même résolution (voir [CameraLockOnPositionOverlay]) et n'a
  /// donc rien de plus à faire ici. `custom-data` fait de même pour
  /// `customDataLoaded`, voir [CustomDataOverlay]. `category-highlight` fait
  /// de même pour `categoriesLoaded`, voir [CategoryHighlightOverlay].
  /// `dynamic-poi-crud` fait de même pour `dynamicPoiCreated`/
  /// `dynamicPoiLabelUpdated`/`dynamicPoiRemoved`, voir [DynamicPoiCrudOverlay].
  /// `runtime-locale` fait de même pour `localesLoaded`, voir
  /// [RuntimeLocaleOverlay]. `native-ui-replacement` n'en a pas besoin non
  /// plus : son panneau ([NativeUiReplacementMapPanel]) embarque directement
  /// [FloorSelectorOverlay], qui gère déjà `venueLayout`/`floorChanged` lui-même.
  /// `explore-mode` fait de même pour `exploreMode`/`exploreModeChanged`,
  /// voir [ExploreModeOverlay]. `add-locale` fait de même pour
  /// `spanishLocaleAdded`, voir [AddLocaleOverlay].
  void onMapMessage(BuildContext context, VisioOneMessage message) {
    switch (this) {
      case Feature.poiClick:
        handlePoiSelectedMessage(context, message);
      case Feature.resetView:
      case Feature.occupancySimulated:
      case Feature.gotoPoi:
      case Feature.floorSelector:
      case Feature.computeNavigation:
      case Feature.uiPartVisibility:
      case Feature.simulatedPosition:
      case Feature.cameraLockOnPosition:
      case Feature.clickableSurface:
      case Feature.customData:
      case Feature.categoryHighlight:
      case Feature.dynamicPoiCrud:
      case Feature.runtimeLocale:
      case Feature.nativeUiReplacement:
      case Feature.exploreMode:
      case Feature.addLocale:
        break;
    }
  }
}
