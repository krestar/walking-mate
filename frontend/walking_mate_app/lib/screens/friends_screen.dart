import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/friend_model.dart';
import 'package:walking_mate_app/screens/chat_screen.dart';
import 'package:walking_mate_app/services/friend_service.dart';
import 'package:walking_mate_app/services/realtime_service.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  final RealtimeService _realtimeService = RealtimeService();

  Future<Map<String, List<Friend>>>? _requestsFuture;
  Future<List<Friend>>? _friendsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
    _realtimeService.listenToFriendUpdates(() {
      if (mounted) {
        _loadAllData();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _requestsFuture = _friendService.getAllRequests();
      _friendsFuture = _friendService.getFriends();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color themeColor = Color(0xFF3ED2B3);
    return Scaffold(
      appBar: AppBar(
        title: const Text('워킹메이트 관리'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: themeColor,
          tabs: const [
            Tab(text: '나의 워킹메이트'),
            Tab(text: '받은 요청'),
            Tab(text: '보낸 요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(isReceived: true),
          _buildRequestsList(isReceived: false),
        ],
      ),
    );
  }

  Widget _buildEmptyListIndicator(
      String message, Future<void> Function() onRefresh) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          child: Text(message),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return FutureBuilder<List<Friend>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyListIndicator('아직 워킹메이트가 없습니다.', _loadAllData);
        }
        final friends = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  onTap: () {
                    if (friend.chatRoomId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoomId: friend.chatRoomId!,
                            friendId: friend.userId,
                            friendNickname: friend.nickname,
                          ),
                        ),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    backgroundImage: (friend.profileImageUrl != null)
                        ? NetworkImage(
                            '${ApiConfig.baseUrl.replaceAll("/api", "")}/${friend.profileImageUrl}')
                        : null,
                    child: (friend.profileImageUrl == null)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(friend.nickname),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _handleDeleteFriend(friend),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestsList({required bool isReceived}) {
    return FutureBuilder<Map<String, List<Friend>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return _buildEmptyListIndicator('요청 목록을 불러올 수 없습니다.', _loadAllData);
          }
          final requests = isReceived
              ? snapshot.data!['received']!
              : snapshot.data!['sent']!;
          if (requests.isEmpty) {
            return _buildEmptyListIndicator(
                isReceived ? '받은 요청이 없습니다.' : '보낸 요청이 없습니다.', _loadAllData);
          }
          return RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (request.profileImageUrl != null)
                            ? NetworkImage(
                                '${ApiConfig.baseUrl.replaceAll("/api", "")}/${request.profileImageUrl}')
                            : null,
                        child: (request.profileImageUrl == null)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(request.nickname),
                      trailing: isReceived
                          ? _buildRequestActionButtons(request)
                          : _buildCancelButton(request),
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  Row _buildRequestActionButtons(Friend request) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 28),
          onPressed: () => _handleAcceptRequest(request),
          tooltip: '수락',
        ),
        IconButton(
          icon: const Icon(Icons.highlight_off, color: Colors.red, size: 28),
          onPressed: () => _handleRejectRequest(request),
          tooltip: '거절',
        ),
      ],
    );
  }

  Widget _buildCancelButton(Friend request) {
    return OutlinedButton(
      child: const Text('요청 취소'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
      ),
      onPressed: () => _handleRejectRequest(request),
    );
  }

  void _handleAcceptRequest(Friend request) async {
    try {
      await _friendService.acceptFriendRequest(request.friendshipId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('요청 수락 실패: $e')));
      }
    }
  }

  void _handleRejectRequest(Friend request) async {
    try {
      await _friendService.rejectOrCancelRequest(request.friendshipId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('요청 처리 실패: $e')));
      }
    }
  }

  void _handleDeleteFriend(Friend friend) async {
    try {
      await _friendService.deleteFriend(friend.friendshipId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('친구 삭제 실패: $e')));
      }
    }
  }
}
