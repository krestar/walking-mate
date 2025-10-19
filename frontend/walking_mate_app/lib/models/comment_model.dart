class Crew {
  final int id;
  final String name;
  final String description;
  final int memberCount;
  final int leaderId;

  Crew({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.leaderId,
  });

  factory Crew.fromJson(Map<String, dynamic> json) {
    return Crew(
      id: json['crew_id'],
      name: json['crew_name'] ?? '알 수 없는 크루',
      description: json['description'] ?? '',
      memberCount: json['member_count'] ?? 0,
      leaderId: json['leader_id'],
    );
  }
}

class Post {
  final int postId;
  final int userId;
  final String title;
  final String content;
  final String nickname;
  final DateTime createdAt;

  Post({
    required this.postId,
    required this.userId,
    required this.title,
    required this.content,
    required this.nickname,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      postId: json['post_id'],
      userId: json['user_id'],
      title: json['title'] ?? '제목 없음',
      content: json['content'] ?? '',
      nickname: json['nickname'] ?? '알 수 없음',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class UserSearchResult {
  final int userId;
  final String nickname;

  UserSearchResult({required this.userId, required this.nickname});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      userId: json['user_id'],
      nickname: json['nickname'] ?? '알 수 없는 사용자',
    );
  }
}

class CrewSearchResult {
  final int crewId;
  final String crewName;
  final int memberCount;

  CrewSearchResult(
      {required this.crewId,
      required this.crewName,
      required this.memberCount});

  factory CrewSearchResult.fromJson(Map<String, dynamic> json) {
    return CrewSearchResult(
      crewId: json['crew_id'],
      crewName: json['crew_name'] ?? '알 수 없는 크루',
      memberCount: json['member_count'] ?? 0,
    );
  }
}

