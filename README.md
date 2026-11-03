# Car Counter AI (YOLO Real-Time Vehicle Tracking & Counting)

High-performance real-time AI vehicle counter built with Flutter and Ultralytics YOLO (`yolo26n`).

---

## ⚡ Performance & Refactoring Optimizations

1. **Zero-Inference Rebuilds (Garbage Collection & Frame Drop Prevention)**:
   - Detections are processed in memory and published through narrow
     `ValueNotifier`s, so the camera layer never rebuilds during inference.
   - The HUD, controls and counting-line overlay are wrapped in
     `RepaintBoundary`s, isolating their repaints from the camera texture.
2. **Allocation-Free Tracking Loop**:
   - Detection buffers are reused between frames instead of allocating a list of
     records, a matched-id `Set` and a `removeWhere` closure on every frame.
   - A monotonic frame stamp on each track replaces hash-based match bookkeeping,
     and lost tracks are compacted in place.
   - Track history uses a fixed-size `Float32List` ring buffer, so trajectory
     updates are O(1) and never shift the list.
   - `CounterStats` stores per-type counts in a fixed four-element list with value
     equality, avoiding a map rebuild for every counted vehicle.
   - `VehicleType.fromClassName` resolves lowercase YOLO labels with a direct
     switch, skipping `trim()`/`toLowerCase()` allocations per detection.
3. **Live Configuration Without Page Rebuilds**:
   - `VehicleTracker` exposes a `ValueNotifier<CounterConfig>`; adjusting the
     counting line or confidence slider updates only the overlay/settings sheet,
     not the full page.
4. **Optimized Spatial Tracking Engine**:
   - Uses **squared Euclidean distance** ($dx^2 + dy^2$), avoiding `sqrt()` during
     multi-object matching.
   - Adds **motion vector extrapolation** to keep fast-moving vehicles associated.
   - Requires `minHits` confirmations before accepting a crossing and caps
     simultaneous tracks with `maxTracks`, filtering detector noise.
5. **Batched Overlay Painting**:
   - All dashes of the counting barrier are accumulated into a single `Path`
     (two `drawPath` calls instead of two `drawLine` calls per dash), and the
     badge `TextPainter` layout is cached.
6. **Live Performance Telemetry**:
   - A `Stopwatch`-based `fpsNotifier` reports the measured detection callback
     rate in the HUD, sampled twice per second without timers.
   - Frame processing pauses automatically while the app is backgrounded.
7. **Multi-Vehicle Support & Directional Flow**:
   - Cars, buses, trucks and motorcycles are classified from YOLO COCO labels,
     with per-type counters and inbound/outbound direction tracking.
8. **Configurable Counting Barrier**:
   - Switch between **vertical** and **horizontal** counting lines and adjust line
     position (10%–90%) or the minimum confidence threshold from the settings sheet.

---

## 🧪 Tests

```bash
flutter test
```

Covers class mapping, immutable stats, ring-buffer history, config notifications,
inbound/outbound crossings, `minHits` gating, track pruning, `maxTracks` and
background pausing.

---

## 📁 Project Architecture

```
lib/
├── main.dart                      # App entry point, lifecycle & camera setup
├── models/
│   ├── counter_stats.dart         # Immutable statistics & vehicle metrics
│   ├── vehicle_track.dart         # Active track state, velocity & ring buffer
│   └── vehicle_type.dart          # Enum mapping COCO labels, icons & colors
├── services/
│   └── vehicle_tracker.dart       # Core tracking & line-crossing logic
└── widgets/
    ├── counting_line_painter.dart # High-performance barrier line painter
    ├── hud_header.dart            # Top stats dashboard & category chips
    ├── hud_bottom_controls.dart   # Bottom action controls (Reset, Settings)
    └── settings_sheet.dart        # Real-time parameter tuning sheet
```
