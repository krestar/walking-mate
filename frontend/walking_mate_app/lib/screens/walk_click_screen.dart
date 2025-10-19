import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/models/walkway_model.dart';
import 'package:walking_mate_app/screens/walk_practice_screen.dart';
import 'package:walking_mate_app/services/walkway_service.dart';
import 'package:walking_mate_app/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class WalkClickScreen extends StatefulWidget {
  final int walkwayId;

  const WalkClickScreen({required this.walkwayId, super.key});

  @override
  State<WalkClickScreen> createState() => _WalkClickScreenState();
}

class _WalkClickScreenState extends State<WalkClickScreen> {
  final WalkwayService _walkwayService = WalkwayService();
  final AuthService _authService = AuthService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<Walkway>? _walkwayFuture;
  Future<List<Comment>>? _commentsFuture;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _captureAndUploadThumbnail(Walkway walkway) async {
    if (walkway.thumbnailUrl != null) return;

    try {
      await Future.delayed(const Duration(seconds: 2));
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        await _walkwayService.uploadThumbnail(walkway.walkwayId, imageBytes);
      }
    } catch (e) {
      print("썸네일 캡처 및 업로드 실패: $e");
    }
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

  Future<void> _loadAllData() async {
    await _loadCurrentUser();
    if (mounted) {
      setState(() {
        _walkwayFuture = _walkwayService.getWalkwayById(widget.walkwayId);
        _commentsFuture = _walkwayService.getComments(widget.walkwayId);
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
      print("Error loading user profile in WalkClickScreen: $e");
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    _commentFocusNode.unfocus();

    try {
      await _walkwayService.createComment(
          widget.walkwayId, _commentController.text.trim());
      _commentController.clear();
      _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await _walkwayService.deleteComment(widget.walkwayId, commentId);
      _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteWalkway(BuildContext context) async {
    try {
      await _walkwayService.deleteWalkway(widget.walkwayId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, Walkway walkway) async {
    final titleController = TextEditingController(text: walkway.title);
    final descriptionController =
        TextEditingController(text: walkway.description);
    bool isPublic = walkway.status == 'public';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextField(controller: titleController),
                    TextField(controller: descriptionController, maxLines: 3),
                    SwitchListTile(
                      title: const Text('산책로 공개'),
                      value: isPublic,
                      onChanged: (bool value) {
                        setState(() { isPublic = value; });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책로 정보'),
        actions: [
          FutureBuilder<Walkway>(
            future: _walkwayFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && _currentUserId != null && _currentUserId == snapshot.data!.userId) {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, snapshot.data!);
                    } else if (value == 'delete') {
                      _deleteWalkway(context);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'edit', child: Text('수정')),
                    const PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FutureBuilder<Walkway>(
                      future: _walkwayFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                        } else if (snapshot.hasError) {
                          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
                        } else if (!snapshot.hasData) {
                          return const Center(child: Text('산책로 정보를 불러올 수 없습니다.'));
                        }
                        final walkway = snapshot.data!;
                        return _buildWalkwayDetails(context, walkway);
                      },
                    ),
                  ],
                ),
              ),
            ),
            _buildCommentInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkwayDetails(BuildContext context, Walkway walkway) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(walkway.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildTag('${walkway.estimatedTime}분', Colors.orange),
                  _buildTag(walkway.difficulty ?? '보통', Colors.pink),
                  ...walkway.tags.map((tag) => _buildTag(tag.toString(), Colors.blue)).toList(),
                ],
              ),
              if (walkway.description != null && walkway.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(walkway.description!, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Screenshot(
              controller: _screenshotController,
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: walkway.pathData.isNotEmpty ? NLatLng(walkway.pathData.first[1], walkway.pathData.first[0]) : const NLatLng(37.5666102, 126.9783881),
                    zoom: 15,
                  ),
                  logoClickEnable: false,
                  scaleBarEnable: false,
                  zoomGesturesEnable: false,
                  scrollGesturesEnable: false,
                ),
                onMapReady: (controller) {
                  if (walkway.pathData.isNotEmpty) {
                    final pathOverlay = NPathOverlay(id: 'path', coords: walkway.pathData.map((p) => NLatLng(p[1], p[0])).toList());
                    controller.addOverlay(pathOverlay);
                    final bounds = NLatLngBounds.from(pathOverlay.coords);
                    controller.updateCamera(NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(60)));
                    _captureAndUploadThumbnail(walkway);
                  }
                },
              ),
            ),
          ),
        ),
        _buildCommentsList(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn('거리', '${walkway.distance?.toStringAsFixed(2)}km'),
              _buildInfoColumn('예상 시간', '${walkway.estimatedTime}분'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _toggleLike(walkway),
                icon: Icon(walkway.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined),
                label: Text(walkway.likeCount.toString()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: walkway.isLiked ? Colors.white : Colors.blue,
                  backgroundColor: walkway.isLiked ? Colors.blue : null,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _shareWalkway(walkway),
                icon: const Icon(Icons.share_outlined),
                label: const Text('공유'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalkPracticeScreen(walkway: walkway))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3ED2B3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('산책 하러가기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text("댓글", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        FutureBuilder<List<Comment>>(
          future: _commentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('댓글을 불러올 수 없습니다: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('가장 먼저 댓글을 남겨보세요!')));
            }
            final comments = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Text(comment.nickname.isNotEmpty ? comment.nickname[0] : '?', style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(comment.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(DateFormat('HH:mm').format(comment.createdAt.toLocal()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  if (_currentUserId != null && _currentUserId == comment.userId)
                                    SizedBox(
                                      height: 24, width: 24,
                                      child: IconButton(padding: EdgeInsets.zero, iconSize: 16, icon: const Icon(Icons.close), onPressed: () => _deleteComment(comment.commentId)),
                                    )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(comment.content),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF3ED2B3), foregroundColor: Colors.white),
            icon: const Icon(Icons.send),
            onPressed: _postComment,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}