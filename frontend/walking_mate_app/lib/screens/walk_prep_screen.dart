import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:walking_mate_app/models/walkway_model.dart';
import 'package:walking_mate_app/screens/walk_creation_screen.dart';
import 'package:walking_mate_app/screens/walk_click_screen.dart';
import 'package:walking_mate_app/services/auth_service.dart';
import 'package:walking_mate_app/services/walkway_service.dart';

class WalkPrepScreen extends StatefulWidget {
  const WalkPrepScreen({super.key});

  @override
  State<WalkPrepScreen> createState() => _WalkPrepScreenState();
}

class _WalkPrepScreenState extends State<WalkPrepScreen> {
  final WalkwayService _walkwayService = WalkwayService();
  final AuthService _authService = AuthService();
  Future<List<Walkway>>? _walkwaysFuture;
  String _selectedTab = 'All';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() {
    _loadCurrentUser();
    _loadWalkways();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      if (mounted) {
        setState(() {
          _currentUserId = userProfile['user_id'];
        });
      }
    } catch (e) {
      print("Error loading user profile: $e");
    }
  }

  void _loadWalkways() {
    setState(() {
      _walkwaysFuture = _walkwayService.getWalkways();
    });
  }

  void _toggleLike(Walkway walkway) async {
    final wasLiked = walkway.isLiked;
    setState(() {
      walkway.isLiked = !wasLiked;
      walkway.likeCount += wasLiked ? -1 : 1;
    });

    try {
      if (wasLiked) {
        await _walkwayService.unlikeWalkway(walkway.walkwayId);
      } else {
        await _walkwayService.likeWalkway(walkway.walkwayId);
      }
    } catch (e) {
      setState(() {
        walkway.isLiked = wasLiked;
        walkway.likeCount += wasLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 실패: ${e.toString()}')),
        );
      }
    }
  }

  void _shareWalkway(Walkway walkway) async {
    final text = 'Walking Mate에서 멋진 산책로를 발견했어요!\n\n"${walkway.title}"\n같이 걸어볼래요?';
    if (walkway.thumbnailUrl == null || walkway.thumbnailUrl!.isEmpty) {
      await Share.share(text);
      return;
    }

    try {
      final response = await http.get(Uri.parse(walkway.thumbnailUrl!));
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/walkway_thumbnail.png').writeAsBytes(bytes);
      
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: text);
    } catch (e) {
      await Share.share(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('산책 준비', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadWalkways();
                },
                child: FutureBuilder<List<Walkway>>(
                  future: _walkwaysFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('오류가 발생했습니다:\n${snapshot.error}'),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('생성된 산책로가 없습니다.'));
                    }

                    final walkways = snapshot.data!;
                    return ListView.builder(
                      itemCount: walkways.length,
                      itemBuilder: (context, index) {
                        return _buildWalkwayCard(walkways[index]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const WalkCreationScreen()),
          );
          if (result == true) {
            _loadWalkways();
          }
        },
        backgroundColor: const Color(0xFF3ED2B3),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildWalkwayCard(Walkway walkway) {
    final bool isMyWalkway = _currentUserId == walkway.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  WalkClickScreen(walkwayId: walkway.walkwayId),
            ),
          );
          if (result == true) {
            _loadWalkways();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: (walkway.thumbnailUrl != null && walkway.thumbnailUrl!.isNotEmpty)
                      ? Image.network(
                          walkway.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.map_outlined, color: Colors.grey, size: 40);
                          },
                        )
                      : const Icon(Icons.map_outlined, color: Colors.grey, size: 40),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(walkway.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(walkway.nickname ?? '알 수 없는 사용자', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTag('${walkway.estimatedTime}분', Colors.orange),
                        const SizedBox(width: 8),
                        _buildTag(walkway.difficulty ?? '보통', Colors.pink),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isMyWalkway ? Icons.share_outlined : (walkway.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined),
                      color: isMyWalkway ? Colors.grey[600] : (walkway.isLiked ? Colors.blue : Colors.grey[600]),
                    ),
                    onPressed: () {
                      if (isMyWalkway) {
                        _shareWalkway(walkway);
                      } else {
                        _toggleLike(walkway);
                      }
                    },
                  ),
                  if (!isMyWalkway)
                    Text(
                      walkway.likeCount.toString(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}