import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/achievement_model.dart';
import 'package:walking_mate_app/services/achievement_service.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  final AchievementService _achievementService = AchievementService();
  Future<Map<String, dynamic>>? _achievementsFuture;
  final ValueNotifier<int> _userPoints = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() {
    final future = _achievementService.getAchievements();
    setState(() {
      _achievementsFuture = future;
    });
    future.then((data) {
      if (mounted) {
        _userPoints.value = data['userProfile']['points'] ?? 0;
      }
    }).catchError((error) {
      // Handle error if needed
    });
    return future;
  }

  Future<void> _claimReward(int achievementId) async {
    try {
      final result = await _achievementService.claimReward(achievementId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '보상을 획득했습니다!')),
      );
      _userPoints.value = result['newTotalPoints'] ?? _userPoints.value;
      _loadAchievements();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보상 수령에 실패했습니다: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('업적'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.star, color: Colors.amber),
              label: ValueListenableBuilder<int>(
                valueListenable: _userPoints,
                builder: (context, points, child) {
                  return Text(
                    '$points P',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                },
              ),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAchievements,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _achievementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('업적을 불러오는 데 실패했습니다.\n${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!['achievements'] == null) {
              return const Center(child: Text('업적 데이터가 없습니다.'));
            }

            final List<Achievement> allAchievements =
                (snapshot.data!['achievements'] as List)
                    .map((json) => Achievement.fromJson(json))
                    .toList();

            final inProgressAchievements =
                allAchievements.where((a) => a.status != 'rewarded').toList();
            final rewardedAchievements =
                allAchievements.where((a) => a.status == 'rewarded').toList();

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildAchievementSection(
                    '수행 중인 업적 (${inProgressAchievements.length})',
                    inProgressAchievements),
                const SizedBox(height: 24),
                _buildAchievementSection(
                    '완료한 업적 (${rewardedAchievements.length})',
                    rewardedAchievements),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAchievementSection(
      String title, List<Achievement> achievements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (achievements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('해당하는 업적이 없습니다.')),
          )
        else
          ...achievements
              .map((achievement) => _buildAchievementTile(achievement)),
      ],
    );
  }

  Widget _buildAchievementTile(Achievement achievement) {
    final bool isCompleted = achievement.status == 'completed';
    final bool isRewarded = achievement.status == 'rewarded';
    final double progress =
        achievement.goal > 0 ? (achievement.progress / achievement.goal) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isRewarded ? Icons.check_circle : Icons.emoji_events,
              color: isRewarded
                  ? Colors.grey
                  : (isCompleted ? Colors.amber : Colors.teal),
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          achievement.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (achievement.rewardPoints > 0)
                        Chip(
                          label: Text('+${achievement.rewardPoints} P'),
                          labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                          backgroundColor: Colors.amber.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (!isRewarded) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? Colors.amber : Colors.teal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${achievement.progress} / ${achievement.goal}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted)
              ElevatedButton(
                onPressed: () => _claimReward(achievement.achievementId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: const StadiumBorder(),
                ),
                child: const Text('받기'),
              ),
            if (isRewarded)
              Text(
                '획득 완료',
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
