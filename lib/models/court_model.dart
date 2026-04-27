import 'dart:convert';

class CourtModel {
  final int id;
  final String name;
  final String? type;
  final String? governorate;
  final String? district;
  final String? address;
  final String? locationUrl;
  final double? latitude;
  final double? longitude;
  final List<String>? specializations;

  CourtModel({
    required this.id,
    required this.name,
    this.type,
    this.governorate,
    this.district,
    this.address,
    this.locationUrl,
    this.latitude,
    this.longitude,
    this.specializations,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['court_type_name'],
      governorate: json['governorate_name'],
      district: json['district_name'],
      address: json['address'],
      locationUrl: json['location_url'],
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'court_type_name': type,
      'governorate_name': governorate,
      'district_name': district,
      'address': address,
      'location_url': locationUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
