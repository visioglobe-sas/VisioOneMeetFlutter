# Camera showcase

## Description

An automatic camera tour of the map, for kiosks and lobby screens: the camera flies through a fixed list of POIs, in order, forever — switching floor and building as needed — and pauses as soon as someone touches the map, then resumes on its own after 10 seconds without a touch.

It is built on the camera animation methods of the view — `view.goToFloor(floor, animationOptions)` and `view.goToPOI(poi, animationOptions)` — and on the `AnimationPromise` they return (a `Promise<void>` with an `isCanceled` flag and a `cancel()` method). The SDK has no built-in "tour" or "idle" mode: the loop, the touch detection and the idle timer are app code, running in the page that hosts the map.

For each stop, the tour does:

1. `await view.goToFloor(poi.floor, { duration: 800 })`
2. `await view.goToPOI(poi, { duration: 2500, easing: 'easeInOutQuad', orientation: { heading: index * 90, pitch: 30 } })`
3. wait 3 s, then move on to the next stop (back to the first one after the last).

## SDK usage

Native side — two bridge calls, and one message that reports the tour's state back (on every stop, pause, resume and stop, including when the change came from a touch on the map or from the idle timer, not from the native side):

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> startCarousel(List<String> poiIds) => _call('startCarousel', [poiIds]);
Future<void> stopCarousel() => _run('window.MapBridge.stopCarousel()');

// 'carouselState' message data:
// { state: 'running' | 'paused' | 'stopped', index: 1-based stop number or null, total, poiId }
```

```dart
controller.startCarousel(['B4-UL00-ID0009', 'B1-LL01-ID0152', 'B3-UL00-ID0064', 'B4-UL03-ID0015']);
```

JS side (`assets/www/map.html`) — the loop. Each start/pause/stop increments a run id, so there is only ever one live loop: an older loop notices on its next `await` and exits.

```js
async function carouselLoop(runId) {
  function alive(animation) {
    return runId === carousel.runId && view && !(animation && animation.isCanceled);
  }
  while (alive()) {
    var index = carousel.nextIndex % carousel.stops.length;
    var poi = venue.pois.find(function (p) { return p.id === carousel.stops[index]; });
    carousel.nextIndex = index + 1;

    // Documented order: goToFloor first when the POI is on another floor.
    var toFloor = (carousel.animation = view.goToFloor(poi.floor, { duration: 800 }));
    await toFloor;
    if (!alive(toFloor)) return;

    var toPoi = (carousel.animation = view.goToPOI(poi, {
      duration: 2500,
      easing: 'easeInOutQuad',
      orientation: { heading: index * 90, pitch: 30 }, // degrees
    }));
    await toPoi;
    if (!alive(toPoi)) return;
    carousel.animation = null;

    await dwell(3000);
  }
}
```

Pausing on touch — the SDK gives no "camera moved by the user" event, so the page listens to pointer events on the map container itself, in the capture phase (before the SDK sees them):

```js
['pointerdown', 'pointermove', 'pointerup', 'pointercancel', 'wheel'].forEach(function (type) {
  container.addEventListener(type, onUserInput, { capture: true, passive: true });
});

function onUserInput(event) {
  if (carousel.state === 'stopped') return;
  if (event.type === 'pointermove' && !event.buttons) return; // ignore mouse hover
  if (carousel.state === 'running') {
    carousel.runId++;                                // ends the current loop
    if (carousel.animation) carousel.animation.cancel(); // stops the camera where it is (see below)
    carousel.animation = null;
    carousel.state = 'paused';
  }
  clearTimeout(carousel.resumeTimer);                // every touch restarts the 10 s idle delay
  carousel.resumeTimer = setTimeout(resumeFromNextStop, 10000);
}
```

Stopping — `stopCarousel` only stops scheduling (run id incremented, timers cleared). By design it does **not** cancel an animation in flight: the camera finishes its current hop, and no further hop starts.

## Things to know

- **`goToFloor` before `goToPOI`.** The SDK documentation says the caller is responsible for calling `goToFloor(poi.floor)` before `goToPOI(poi)` when the POI is on another floor, otherwise the current floor/building stays active. In SDK 1.1.0 `goToPOI` alone did switch the floor in our tests, but follow the documented order.
- **The floor switch happens at the start of the animation.** `view.currentFloor` changes to the destination floor as soon as `goToFloor`/`goToPOI` starts, not when the camera arrives — even if the animation is cancelled right away.
- **`AnimationOptions.orientation`** sets the final camera orientation: `{ heading?: number | 'initial', pitch?: number | 'initial' }`, in degrees (heading relative to north; pitch 0 = looking straight down, 90 = horizon). `easing` takes an animejs Penner function name (e.g. `'easeInOutQuad'`, `'linear'`); `duration` is in milliseconds.
- **A new camera animation interrupts the running one.** Starting `goToFloor`/`goToPOI`/`goToViewpoint`/`goToGlobal` while another camera animation runs makes the running one's promise resolve with `isCanceled === true`, and the camera continues from where it was. A loop must therefore check `isCanceled` (and its own "still running?" state) after every `await`, or it will happily start its next hop on top of whatever interrupted it.
- **User gestures do not interrupt SDK animations, and there is no "camera moved by the user" event.** A drag on the map during a `goToPOI` animation does not stop it — the animation keeps running to its end and the user fights the camera. To give the user's gesture priority, detect touches yourself (pointer events on the map container, capture phase) and interrupt the animation.
- **`cancel()` vs. the documentation.** The SDK's public typing says `cancel()` "puts the animation target in its final state": that wording is wrong. The SDK core implementation (1.1.0) documents and implements `cancel()` as leaving the animation target in the state it is in at the moment of the call, and live measurements confirm it. In this app (SDK 1.1.0, iOS WKWebView), `cancel()` instead **stopped the camera where it was**, every time: cancelled synchronously right after starting, after 50 ms, 300 ms or 1.8 s, on both `goToPOI` and `goToFloor` — position, target, heading and pitch stayed on their mid-flight values (e.g. heading 41.6° kept, versus 120° at the destination), confirmed on screenshots; the promise resolved with `isCanceled === true`. The same was measured in an Android `WebView`.
- **A zero-length `goToViewpoint` is not a clean "stop here".** `view.goToViewpoint({ positions: [view.camera.target], targetAltitude: view.camera.target.altitude }, { duration: 0, orientation: { heading: view.camera.heading, pitch: view.camera.pitch } })` does interrupt the running animation (it resolves with `isCanceled === true`), but the resulting view is shifted: about 20 m sideways and 2° of heading at ~160 m camera altitude, about 45 m at ~525 m — proportional to the camera distance, so visible on screen. It is also applied asynchronously (`view.camera` still reports the old values right after the call), so it cannot be corrected in the same tick. That is why this demo pauses with `cancel()`.
- **Known SDK issue (1.1.0): the camera can break after a drag on an underground floor.** Observed on another platform: after `goToPOI` with `orientation: { heading: 90 or 180, pitch: 45 }` on the underground POI `B1-LL01-ID0152` (floor `B1-LL1`, camera at its 10 m minimum altitude), one or two user drags turned `view.camera.heading` into `NaN` and `pitch` into `0`, and the map rendered black until the view was reloaded. It is not systematically reproducible; pitch 30 did not trigger it in the attempts made, so the demo uses `pitch: 30`.
- **`view.camera.heading`/`pitch` setters don't interrupt an animation.** Assigning the current value back (`view.camera.heading = view.camera.heading`) has no effect on a running `goToPOI`: it continues to its destination.
- **A view reload kills the tour.** Everything is tied to the current `view`: if the view is destroyed and recreated (e.g. to change projection), stop the loop first and start it again on the new view.
- **Synthetic pointer events in tests.** Dispatching a synthetic `PointerEvent('pointerdown')` directly on the SDK's `<canvas>` (as an automated test might) makes the SDK throw an uncaught error (reported as `Script error.` from the SDK bundle), presumably because the pointer id is not a real active pointer. Real touches don't. Dispatch test events on the container instead.

## Learn more

- [Go to POI](goto-poi.md) — a single `goToFloor` + `goToPOI` hop.
- [Floor selector](floor-selector.md) — `goToFloor` and the `currentfloorchanged` event.
