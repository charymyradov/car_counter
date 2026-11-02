# Car Counter AI (YOLO Real-Time Vehicle Tracking & Counting)

High-performance real-time AI vehicle counter built with Flutter and Ultralytics YOLO (`yolo26n`).

---

## ⚡ Performance & Refactoring Optimizations

1. **Zero-Inference Rebuilds (Garbage Collection & Frame Drop Prevention)**:
   - Previously, every incoming detection frame called `setState()`, causing the entire widget tree (including camera and painter) to rebuild 30–60 times per second.
   - Refactored to reactive `ValueNotifier<CounterStats>` and `ValueNotifier<int>`. Detections are processed in memory and UI elements update isolatedly without dropping camera frames.
2. **Optimized Spatial Tracking Engine**:
   - Replaced naive Euclidean distance checks with **squared Euclidean distance** ($dx^2 + dy^2$) avoiding expensive `sqrt()` operations during multi-object matching.
   - Added **motion vector extrapolation / velocity prediction** to maintain track stability for faster-moving vehicles.
3. **Multi-Vehicle Support**:
   - Integrated `VehicleType` (Cars, Buses, Trucks, Motorcycles) using YOLO COCO classification.
   - Live breakdown metrics with individual counters and type-specific visual identifiers.
4. **Directional Flow Analysis**:
   - Tracks whether vehicles are crossing inbound (left-to-right / top-to-bottom) or outbound.
5. **Configurable Counting Barrier**:
   - Switch between **Vertical** and **Horizontal** counting lines.
   - Adjust line position (10% to 90%) and minimum confidence threshold directly from the live settings modal.
6. **Zero-Allocation Custom Painter**:
   - Reused cached `Paint` instances in `CountingLinePainter` to eliminate micro-allocations in render passes.

---

## 📁 Project Architecture

```
lib/
├── main.dart                      # App entry point, lifecycle & camera setup
├── models/
│   ├── counter_stats.dart         # Immutable statistics & vehicle metrics
│   ├── vehicle_track.dart         # Active track state, velocity vector & trajectory
│   └── vehicle_type.dart          # Enum mapping COCO labels, icons & colors
├── services/
│   └── vehicle_tracker.dart       # Core tracking & line-crossing logic
└── widgets/
    ├── counting_line_painter.dart # High-performance barrier line painter
    ├── hud_header.dart            # Top stats dashboard & category chips
    ├── hud_bottom_controls.dart   # Bottom action controls (Reset, Settings)
    └── settings_sheet.dart        # Real-time parameter tuning sheet
```
