import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walking_mate_app/providers/character_provider.dart';
import 'package:walking_mate_app/screens/costume_screen.dart';
import 'package:walking_mate_app/services/auth_service.dart';
import 'package:walking_mate_app/services/walkrecord_service.dart';
import 'package:walking_mate_app/widgets/character_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final WalkRecordService _walkRecordService = WalkRecordService();

  String _nickname = '로딩 중...';
  Future<int>? _todayWalkTimeFuture;
  int _walkGoalInMinutes = 60;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _loadUserProfile();
    _loadWalkGoal();
    _loadTodayWalkTime();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      if (!mounted) return;
      setState(() {
        _nickname = userProfile['nickname'] ?? '사용자';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nickname = '정보 로딩 실패';
      });
    }
  }

  Future<void> _loadWalkGoal() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _walkGoalInMinutes = prefs.getInt('walkGoal') ?? 60;
      });
    }
  }

  void _loadTodayWalkTime() {
    if (mounted) {
      setState(() {
        _todayWalkTimeFuture = _walkRecordService.getTodayWalkTime();
      });
    }
  }

  Future<void> _showGoalSettingDialog() async {
    int tempGoal = _walkGoalInMinutes;
    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('목표 산책 시간 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${tempGoal}분', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3ED2B3))),
                  Slider(
                    value: tempGoal.toDouble(),
                    min: 15,
                    max: 180,
                    divisions: (180 - 15) ~/ 15,
                    label: '${tempGoal}분',
                    onChanged: (value) {
                      setDialogState(() {
                        tempGoal = value.round();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('walkGoal', tempGoal);
                    Navigator.of(context).pop(tempGoal);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newGoal != null && mounted) {
      setState(() {
        _walkGoalInMinutes = newGoal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3ED2B3),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Text(
                '$_nickname님, 안녕하세요',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildWalkTimeCard(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildDecorateButton(),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: Consumer<CharacterProvider>(
                            builder: (context, provider, child) {
                              return const CharacterView(animationType: 'dance');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FutureBuilder<int>(
        future: _todayWalkTimeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('시간을 불러올 수 없습니다.'));
          }

          final totalSeconds = snapshot.data ?? 0;
          final currentWalkMinutes = totalSeconds ~/ 60;
          final progress = (_walkGoalInMinutes > 0 ? currentWalkMinutes / _walkGoalInMinutes : 0.0).clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('오늘의 산책시간', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 20),
                    onPressed: _showGoalSettingDialog,
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      '${currentWalkMinutes}min',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ $_walkGoalInMinutes' 'min',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDecorateButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3ED2B3), width: 2),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CostumeScreen()),
              );
            },
            icon: const Icon(Icons.checkroom, color: Color(0xFF3ED2B3), size: 24),
          ),
        ),
        const SizedBox(height: 4),
        const Text('꾸미기', style: TextStyle(color: Color(0xFF3ED2B3), fontSize: 12)),
      ],
    );
  }
}