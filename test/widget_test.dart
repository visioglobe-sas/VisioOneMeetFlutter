// Teste le contrat du pont JS -> Native ([VisioOneMessage]) et le test de
// containment de `geofencing` ([isPointInPolygon]) : la logique pure (sans
// WebView / platform channels) de ce projet.
//
// Un test de widget complet nécessiterait de mocker le platform channel de
// webview_flutter (WebViewController, JavaScriptChannel...) : hors périmètre
// de ce squelette d'intégration.

import 'package:flutter_test/flutter_test.dart';
import 'package:visio_one_meet_flutter/visio_one/geofence_utils.dart';
import 'package:visio_one_meet_flutter/visio_one/simulated_position_session.dart';
import 'package:visio_one_meet_flutter/visio_one/visio_one_message.dart';

void main() {
  group('VisioOneMessage.tryParse', () {
    test('parses a message without data', () {
      final message = VisioOneMessage.tryParse('{"type":"ready"}');
      expect(message?.type, 'ready');
      expect(message?.data, isNull);
    });

    test('parses a message with structured data', () {
      final message = VisioOneMessage.tryParse(
        '{"type":"poiSelected","data":{"id":"B1-UL00-01","name":"Salle A"}}',
      );
      expect(message?.type, 'poiSelected');
      expect((message?.data as Map)['id'], 'B1-UL00-01');
    });

    test('returns null for malformed JSON', () {
      expect(VisioOneMessage.tryParse('not json'), isNull);
    });

    test('returns null when "type" is missing or not a string', () {
      expect(VisioOneMessage.tryParse('{"data":{}}'), isNull);
      expect(VisioOneMessage.tryParse('{"type":42}'), isNull);
    });
  });

  group('isPointInPolygon', () {
    // Carré 1° x 1° en (lat, lng), un ordre de grandeur bien plus grand
    // qu'un vrai POI mais qui garde le test lisible sans perte de généralité
    // pour l'algorithme (ray casting) — voir `geofence_utils.dart`.
    final square = [
      const SimulatedPosition(latitude: 0, longitude: 0),
      const SimulatedPosition(latitude: 0, longitude: 1),
      const SimulatedPosition(latitude: 1, longitude: 1),
      const SimulatedPosition(latitude: 1, longitude: 0),
    ];

    test('returns true for a point inside the polygon', () {
      expect(isPointInPolygon(latitude: 0.5, longitude: 0.5, polygon: square), isTrue);
    });

    test('returns false for a point outside the polygon', () {
      expect(isPointInPolygon(latitude: 2, longitude: 2, polygon: square), isFalse);
    });

    test('returns false for fewer than 3 vertices', () {
      expect(
        isPointInPolygon(
          latitude: 0.5,
          longitude: 0.5,
          polygon: const [SimulatedPosition(latitude: 0, longitude: 0), SimulatedPosition(latitude: 1, longitude: 1)],
        ),
        isFalse,
      );
    });
  });
}
