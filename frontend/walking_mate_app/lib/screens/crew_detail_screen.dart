import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/screens/crew_members_screen.dart';
import 'package:walking_mate_app/screens/post_creation_screen.dart';
import 'package:walking_mate_app/screens/post_edit_screen.dart';
import 'package:walking_mate_app/services/community_service.dart';
import 'package:walking_mate_app/services/auth_service.dart';
import 'package:walking_mate_app/services/report_service.dart';
import 'package:intl/intl.dart';

class CrewDetailScreen extends StatefulWidget {
  final Crew crew;

  const CrewDetailScreen({required this.crew, super.key});

  @override
  State<CrewDetailScreen> createState() => _CrewDetailScreenState();
}

class _CrewDetailScreenState extends State<CrewDetailScreen> {
  final CommunityService _communityService = CommunityService();
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<List<Post>>? _postsFuture;
  int? _currentUserId;
  bool _isLeader = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadCurrentUser();
    if (mounted) {
      setState(() {
        _postsFuture = _communityService.getPosts(widget.crew.id);
        if (_currentUserId != null) {
          _isLeader = widget.crew.leaderId == _currentUserId;
        }
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
      print("Error loading user profile in CrewDetailScreen: $e");
    }
  }

  Future<void> _showReportDialog(Post post) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시물 신고'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: '신고 사유를 입력해주세요.'),
            validator: (value) => (value == null || value.isEmpty) ? '신고 사유는 필수입니다.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                try {
                  final image = await _screenshotController.capture();
                  if (image != null) {
                    await _reportService.submitReport(
                      targetType: 'post',
                      targetId: post.postId.toString(),
                      reason: reasonController.text,
                      screenshotBytes: image,
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신고 접수 실패: $e')));
                }
              }
            },
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.crew.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: _onMenuSelected,
              itemBuilder: (BuildContext context) {
                return [
                  if (_isLeader) const PopupMenuItem<String>(value: 'manage_members', child: Text('멤버 관리')),
                  if (_isLeader) const PopupMenuItem<String>(value: 'delete_crew', child: Text('크루 삭제')),
                  if (!_isLeader) const PopupMenuItem<String>(value: 'leave_crew', child: Text('크루 탈퇴')),
                ];
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadAllData,
          child: FutureBuilder<List<Post>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('게시글을 불러오는 데 실패했습니다: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('아직 작성된 게시글이 없습니다.'));
              }

              final posts = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return _buildPostCard(posts[index]);
                },
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => PostCreationScreen(crewId: widget.crew.id)),
            ).then((success) {
              if (success == true) {
                _loadAllData();
              }
            });
          },
          backgroundColor: const Color(0xFF3ED2B3),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'manage_members':
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => CrewMembersScreen(crew: widget.crew)));
        break;
      case 'delete_crew':
        _confirmAction('크루 삭제', '정말로 이 크루를 삭제하시겠습니까?', () async {
          await _communityService.deleteCrew(widget.crew.id);
          if(mounted) Navigator.of(context).pop(true);
        });
        break;
      case 'leave_crew':
        _confirmAction('크루 탈퇴', '정말로 이 크루를 탈퇴하시겠습니까?', () async {
          await _communityService.leaveCrew(widget.crew.id);
          if(mounted) Navigator.of(context).pop(true);
        });
        break;
    }
  }

  Widget _buildPostCard(Post post) {
    final bool isAuthor = _currentUserId == post.userId;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFFE0F2F1), child: Text(post.nickname.isNotEmpty ? post.nickname[0] : '?')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(DateFormat('MM/dd HH:mm').format(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostEditScreen(post: post))).then((success) {
                         if(success == true) _loadAllData();
                      });
                    } else if (value == 'delete') {
                      _confirmAction('게시글 삭제', '정말로 이 게시글을 삭제하시겠습니까?', () async {
                          await _communityService.deletePost(post.postId);
                          _loadAllData();
                       });
                    } else if (value == 'report') {
                      _showReportDialog(post);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      if(isAuthor) const PopupMenuItem(value: 'edit', child: Text('수정')),
                      if (isAuthor || _isLeader) const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      if (!isAuthor) const PopupMenuItem(value: 'report', child: Text('신고')),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(post.content),
          ],
        ),
      ),
    );
  }

  void _confirmAction(String title, String content, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(child: const Text('취소'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('확인', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                   Navigator.of(context).pop();
                   await onConfirm();
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 실패: $e')));
                }
              },
            ),
          ],
        );
      },
    );
  }
}