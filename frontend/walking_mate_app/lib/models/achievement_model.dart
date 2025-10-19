class UserProfile {
  final int userId;
  final String nickname;
  int points;

  UserProfile({
    required this.userId,
    required this.nickname,
    required this.points,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? 0,
      nickname: json['nickname'] ?? '사용자',
      points: json['points'] ?? 0,
    );
  }
}

class Achievement {
  final int achievementId;
  final String title;
  final String description;
  final String category;
  final int goal;
  final int rewardPoints;
  final int progress;
  final String status;

  Achievement({
    required this.achievementId,
    required this.title,
    required this.description,
    required this.category,
    required this.goal,
    required this.rewardPoints,
    required this.progress,
    required this.status,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      achievementId: json['achievement_id'] ?? 0,
      title: json['title'] ?? '알 수 없는 업적',
      description: json['description'] ?? '',
      category: json['category'] ?? '기타',
      goal: json['goal'] ?? 1,
      rewardPoints: json['reward_points'] ?? 0,
      progress: json['progress'] ?? 0,
      status: json['status'] ?? 'locked',
    );
  }
}

