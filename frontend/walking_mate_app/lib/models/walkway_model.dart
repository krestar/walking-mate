class Walkway {
  final int walkwayId;
  final int userId;
  final String title;
  final String? description;
  final List<List<double>> pathData;
  final double? distance;
  final int? estimatedTime;
  final String? difficulty;
  final List<dynamic> waypoints;
  final String? startLocationName;
  final String? endLocationName;
  final List<dynamic> tags;
  final String status;
  final DateTime createdAt;
  final String? nickname;
  final String? thumbnailUrl;
  int likeCount;
  bool isLiked;

  Walkway({
    required this.walkwayId,
    required this.userId,
    required this.title,
    this.description,
    required this.pathData,
    this.distance,
    this.estimatedTime,
    this.difficulty,
    required this.waypoints,
    this.startLocationName,
    this.endLocationName,
    required this.tags,
    required this.status,
    required this.createdAt,
    this.nickname,
    this.thumbnailUrl,
    required this.likeCount,
    required this.isLiked,
  });

  factory Walkway.fromJson(Map<String, dynamic> json) {
    final pathDataJson = json['path_data'] as Map<String, dynamic>? ?? {};
    final coordinates = (pathDataJson['coordinates'] as List<dynamic>?)
        ?.map<List<double>>((coord) =>
    [(coord[0] as num).toDouble(), (coord[1] as num).toDouble()])
        .toList() ??
        [];

    return Walkway(
      walkwayId: json['walkway_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '제목 없음',
      description: json['description'],
      pathData: coordinates,
      distance: (json['distance'] as num?)?.toDouble(),
      estimatedTime: json['estimated_time'],
      difficulty: json['difficulty'],
      waypoints: json['waypoints'] as List<dynamic>? ?? [],
      startLocationName: json['start_location_name'],
      endLocationName: json['end_location_name'],
      tags: json['tags'] as List<dynamic>? ?? [],
      status: json['status'] ?? 'private',
      createdAt: DateTime.tryParse((json['created_at'] as String? ?? '').replaceAll(' ', 'T')) ?? DateTime.now(),
      nickname: json['nickname'],
      thumbnailUrl: json['thumbnail_url'],
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }
}