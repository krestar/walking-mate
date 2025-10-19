class FrameData {
  final int x;
  final int y;
  final int width;
  final int height;

  FrameData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory FrameData.fromJson(Map<String, dynamic> json) {
    return FrameData(
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }
}

class Character {
  final String id;
  final String name;
  final int price;
  final bool isOwned;
  final Map<String, List<FrameData>> animations;

  Character({
    required this.id,
    required this.name,
    required this.price,
    required this.isOwned,
    required this.animations,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    final animationsData = json['animations'] as Map<String, dynamic>? ?? {};
    final Map<String, List<FrameData>> animations = {};

    animationsData.forEach((key, value) {
      if (value is List) {
        animations[key] = value.map((frameJson) => FrameData.fromJson(frameJson)).toList();
      }
    });

    return Character(
      id: json['character_id'],
      name: json['character_name'],
      price: json['price'] ?? 0,
      isOwned: json['isOwned'] ?? false,
      animations: animations,
    );
  }
}