import 'package:flutter/material.dart';
import '../services/vehicle_tracker.dart';

/// Modal bottom sheet allowing real-time adjustment of detection & counting parameters.
class SettingsSheet extends StatefulWidget {
  final VehicleTracker tracker;
  final ValueChanged<CounterConfig> onConfigChanged;

  const SettingsSheet({
    super.key,
    required this.tracker,
    required this.onConfigChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTracker tracker,
    required ValueChanged<CounterConfig> onConfigChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(
        tracker: tracker,
        onConfigChanged: onConfigChanged,
      ),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late double _linePosition;
  late bool _isHorizontal;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    _linePosition = widget.tracker.config.linePosition;
    _isHorizontal = widget.tracker.config.isHorizontal;
    _confidence = widget.tracker.config.minConfidence;
  }

  void _notifyChange() {
    final updated = widget.tracker.config.copyWith(
      linePosition: _linePosition,
      isHorizontal: _isHorizontal,
      minConfidence: _confidence,
    );
    widget.onConfigChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF14171A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF00E5FF), size: 22),
              SizedBox(width: 8),
              Text(
                'AI Tracker Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Orientation Segment
          const Text(
            'LINE ORIENTATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Vertical Line (Left/Right)'),
                icon: Icon(Icons.swap_horiz_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Horizontal Line (Top/Down)'),
                icon: Icon(Icons.swap_vert_rounded),
              ),
            ],
            selected: {_isHorizontal},
            onSelectionChanged: (set) {
              setState(() {
                _isHorizontal = set.first;
              });
              _notifyChange();
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              selectedForegroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),

          // Line position slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LINE POSITION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${(_linePosition * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              thumbColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              value: _linePosition,
              min: 0.10,
              max: 0.90,
              divisions: 16,
              onChanged: (val) {
                setState(() => _linePosition = val);
                _notifyChange();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Detection confidence slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MIN CONFIDENCE THRESHOLD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${(_confidence * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              thumbColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              value: _confidence,
              min: 0.20,
              max: 0.80,
              divisions: 12,
              onChanged: (val) {
                setState(() => _confidence = val);
                _notifyChange();
              },
            ),
          ),
        ],
      ),
    );
  }
}

