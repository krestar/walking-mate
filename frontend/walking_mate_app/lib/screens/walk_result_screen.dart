import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:walking_mate_app/screens/main_layout_screen.dart';

class WalkResultScreen extends StatefulWidget {
  final int totalTime; // 초 단위
  final double totalDistance; // km 단위
  final Map<String, dynamic> resultData;

  const WalkResultScreen({
    required this.totalTime,
    required this.totalDistance,
    required this.resultData,
    super.key,
  });

  @override
  State<WalkResultScreen> createState() => _WalkResultScreenState();
}

class _WalkResultScreenState extends State<WalkResultScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  double _calculateCalories(double distance) {
    // (몸무게 65kg 기준) x (이동 거리 km)
    const double weight = 65.0;
    return weight * distance;
  }

  void _shareResultAsImage() async {
    final Uint8List? imageBytes = await _screenshotController.capture();

    if (imageBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/walk_result.png').create();
      await imagePath.writeAsBytes(imageBytes);

      final xFile = XFile(imagePath.path);
      await Share.shareXFiles([xFile], text: '오늘의 산책을 완료했어요! 🏃‍♂️');
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnedPoints = widget.resultData['earnedPoints'] ?? 0;
    final newAchievement = widget.resultData['newAchievement'];

    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        backgroundColor: const Color(0xFF3ED2B3),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                const Text(
                  '🎉 산책 완료!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                _buildResultCard(
                  children: [
                    _buildResultItem(
                        '⏱️', '총 산책 시간', _formatDuration(widget.totalTime)),
                    _buildResultItem('📍', '총 산책 거리',
                        '${widget.totalDistance.toStringAsFixed(2)} km'),
                    _buildResultItem('🔥', '소모 칼로리',
                        '${_calculateCalories(widget.totalDistance).toStringAsFixed(0)} kcal'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildResultCard(
                  children: [
                    _buildResultItem(
                        '🧩', '획득 포인트', '+ $earnedPoints P', color: Colors.amber),
                    if (newAchievement != null)
                      _buildResultItem('🏆', '새 업적 달성!', newAchievement['name'], color: Colors.blueAccent),
                  ],
                ),
                const Spacer(flex: 3),
                ElevatedButton(
                  onPressed: _shareResultAsImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3ED2B3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '이미지로 공유하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const MainLayoutScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildResultItem(String icon, String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}