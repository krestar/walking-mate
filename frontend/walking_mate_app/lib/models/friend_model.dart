class Friend {
  final int friendshipId;
  final int userId;
  final String nickname;
  final String status;
  final String? chatRoomId;
  final String? profileImageUrl;

  Friend({
    required this.friendshipId,
    required this.userId,
    required this.nickname,
    required this.status,
    this.chatRoomId,
    this.profileImageUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      friendshipId: json['friendship_id'],
      userId: json['user_id'],
      nickname: json['nickname'] ?? '알 수 없는 사용자',
      status: json['status'] ?? 'pending',
      chatRoomId: json['chat_room_id'],
      profileImageUrl: json['profile_image_url'],
    );
  }
}
