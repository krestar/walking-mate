import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:walking_mate_app/models/friend_model.dart';
import 'package:walking_mate_app/screens/chat_screen.dart';
import 'package:walking_mate_app/screens/friends_screen.dart';
import 'package:walking_mate_app/services/chat_service.dart';
import 'package:walking_mate_app/services/friend_service.dart';

class FriendsAndChatWidget extends StatefulWidget {
  const FriendsAndChatWidget({super.key});

  @override
  State<FriendsAndChatWidget> createState() => _FriendsAndChatWidgetState();
}

class _FriendsAndChatWidgetState extends State<FriendsAndChatWidget> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  Future<List<Friend>>? _friendsFuture;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _friendsFuture = _friendService.getFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Friend>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('친구 목록을 불러오는 데 실패했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('아직 워킹메이트가 없습니다.'));
          }
          final friends = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _loadFriends,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                return _buildChatCard(friends[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FriendsScreen(),
            ),
          );
          if (result == true || result == null && mounted) {
             _loadFriends();
          }
        },
        heroTag: 'friends_fab',
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  Widget _buildChatCard(Friend friend) {
    if (friend.chatRoomId == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.getChatRoomStream(friend.chatRoomId!),
      builder: (context, snapshot) {
        String lastMessage = '대화를 시작해보세요.';
        String lastMessageTime = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          lastMessage = data['lastMessage'] ?? '...';
          final timestamp = data['lastMessageTimestamp'] as Timestamp?;
          if (timestamp != null) {
            final dateTime = timestamp.toDate();
            if (DateUtils.isSameDay(dateTime, DateTime.now())) {
              lastMessageTime = DateFormat('HH:mm').format(dateTime);
            } else {
              lastMessageTime = DateFormat('MM/dd').format(dateTime);
            }
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatRoomId: friend.chatRoomId!,
                    friendId: friend.userId,
                    friendNickname: friend.nickname,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(friend.nickname.isNotEmpty ? friend.nickname[0] : '?'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.nickname,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(lastMessage,
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(lastMessageTime,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
