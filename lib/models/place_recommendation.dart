class PlaceRecommendation {
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;

  PlaceRecommendation({
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceRecommendation.fromJson(Map<String, dynamic> json) {
    return PlaceRecommendation(
      title: json['title'] as String? ?? 'Place',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

