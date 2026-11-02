import 'package:flutter/material.dart';

/// Supported vehicle classes recognized by the AI detector.
enum VehicleType {
  car('Car', Icons.directions_car_rounded, Color(0xFF00E5FF)),
  bus('Bus', Icons.directions_bus_rounded, Color(0xFFFFB300)),
  truck('Truck', Icons.local_shipping_rounded, Color(0xFFFF7043)),
  motorcycle('Motorcycle', Icons.two_wheeler_rounded, Color(0xFF76FF03));

  final String label;
  final IconData icon;
  final Color color;

  const VehicleType(this.label, this.icon, this.color);

  /// Resolves the vehicle type from YOLO COCO class label.
  static VehicleType? fromClassName(String name) {
    final clean = name.trim().toLowerCase();
    switch (clean) {
      case 'car':
      case 'automobile':
      case 'sedan':
      case 'suv':
        return VehicleType.car;
      case 'bus':
        return VehicleType.bus;
      case 'truck':
      case 'pickup':
        return VehicleType.truck;
      case 'motorcycle':
      case 'motorbike':
      case 'scooter':
      case 'bike':
        return VehicleType.motorcycle;
      default:
        return null;
    }
  }

  /// Whether the class name is a recognized vehicle.
  static bool isVehicle(String name) => fromClassName(name) != null;
}
