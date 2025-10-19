import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/services/community_service.dart';
import 'package:walking_mate_app/services/auth_service.dart';

class CrewMembersScreen extends StatefulWidget {
  final Crew crew;
  const CrewMembersScreen({required this.crew, super.key});

  @override
  State<CrewMembersScreen> createState() => _CrewMembersScreenState();
}

class _CrewMembersScreenState extends State<CrewMembersScreen> {
  final CommunityService _communityService = CommunityService();
  final AuthService _authService = AuthService(); // AuthService 인스턴스 생성
  Future<List<CrewMember>>? _membersFuture;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadCurrentUser();
    if (mounted) {
      setState(() {
        _membersFuture = _communityService.getCrewMembers(widget.crew.id);
      });
    }
  }


  Future<void> _loadCurrentUser() async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      if (mounted) {
        _currentUserId = userProfile['user_id'];
      }
    } catch (e) {
      print("Error loading user profile in CrewMembersScreen: $e");
      // TODO: 에러 발생 시 사용자에게 알림 또는 로그아웃 처리
    }
  }


  void _removeMember(int memberId) async {
    try {
      await _communityService.removeCrewMember(widget.crew.id, memberId);
      _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('멤버 추방 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLeader = _currentUserId == widget.crew.leaderId;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.crew.name} 멤버'),
      ),
      body: FutureBuilder<List<CrewMember>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('멤버 목록을 불러오는 데 실패했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('크루 멤버가 없습니다.'));
          }

          final members = snapshot.data!;
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.profileImageUrl != null
                      ? NetworkImage(member.profileImageUrl!)
                      : null,
                  child: member.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(member.nickname),
                subtitle: Text(member.role == 'leader' ? '크루장' : '멤버'),
                trailing: (isLeader && member.role != 'leader')
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () => _removeMember(member.userId),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
