import 'package:flutter/material.dart';
import 'package:walking_mate_app/screens/map_picker_screen.dart';
import 'package:walking_mate_app/services/walkway_service.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class WalkCreationScreen extends StatefulWidget {
  const WalkCreationScreen({super.key});

  @override
  State<WalkCreationScreen> createState() => _WalkCreationScreenState();
}

class _WalkCreationScreenState extends State<WalkCreationScreen> {
  String? _selectedDifficulty;
  final Set<String> _selectedThemes = {};
  String _startLocationName = "위치를 선택해주세요";
  NLatLng? _startLocationCoords;
  String _endLocationName = "위치를 선택해주세요";
  NLatLng? _endLocationCoords;
  double _selectedMinutes = 30.0;
  final _promptController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;

  final List<String> _difficulties = ['쉬움', '보통', '어려움'];
  final List<String> _themes = ['도심', '강변', '숲', '번화가', '사색을 즐기는', '반려견 동반'];

  String _formatDuration(double minutes) {
    if (minutes < 1) return '0분';
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes.toInt() % 60;
    String result = '';
    if (hours > 0) result += '${hours}시간 ';
    if (remainingMinutes > 0) result += '$remainingMinutes분';
    return result.trim();
  }

  void _resetForm() {
    setState(() {
      _selectedDifficulty = null;
      _selectedThemes.clear();
      _startLocationName = "위치를 선택해주세요";
      _startLocationCoords = null;
      _endLocationName = "위치를 선택해주세요";
      _endLocationCoords = null;
      _selectedMinutes = 30.0;
      _promptController.clear();
      _isPublic = true;
    });
  }

  void _selectLocation(bool isStart) async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startLocationName = result.address;
          _startLocationCoords = result.coordinates;
        } else {
          _endLocationName = result.address;
          _endLocationCoords = result.coordinates;
        }
      });
    }
  }

  Future<void> _createWalkway() async {
    if (_startLocationCoords == null || _endLocationCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지와 도착지 위치를 모두 선택해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final walkwayData = {
        "title": "새로운 AI 추천 산책로",
        "description": _promptController.text,
        "difficulty": _selectedDifficulty,
        "start_location_name": _startLocationName,
        "start_coords": {
          "lat": _startLocationCoords!.latitude,
          "lng": _startLocationCoords!.longitude
        },
        "end_location_name": _endLocationName,
        "end_coords": {
          "lat": _endLocationCoords!.latitude,
          "lng": _endLocationCoords!.longitude
        },
        "tags": _selectedThemes.toList(),
        "status": _isPublic ? "public" : "private",
        "estimated_time_label": "약 ${_formatDuration(_selectedMinutes)}",
      };

      await WalkwayService().createWalkway(walkwayData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 산책로가 생성 요청되었습니다!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: ${e.toString()}')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF3ED2B3);

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: themeColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: themeColor,
              secondary: themeColor,
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: themeColor,
                side: const BorderSide(color: themeColor),
                textStyle: const TextStyle(fontWeight: FontWeight.bold))),
        chipTheme: ChipTheme.of(context).copyWith(
          selectedColor: themeColor,
          labelStyle:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          secondaryLabelStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          backgroundColor: Colors.grey[200],
        ),
        sliderTheme: SliderTheme.of(context).copyWith(
          activeTrackColor: themeColor,
          thumbColor: themeColor,
          overlayColor: themeColor.withOpacity(0.2),
          inactiveTrackColor: Colors.grey[300],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('산책로 생성'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('난이도'),
              Wrap(
                spacing: 8.0,
                children: _difficulties.map((difficulty) {
                  return ChoiceChip(
                    label: Text(difficulty),
                    selected: _selectedDifficulty == difficulty,
                    onSelected: (selected) {
                      setState(() {
                        _selectedDifficulty = selected ? difficulty : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('테마'),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _themes.map((theme) {
                  return FilterChip(
                    label: Text(theme),
                    selected: _selectedThemes.contains(theme),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedThemes.add(theme);
                        } else {
                          _selectedThemes.remove(theme);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('출발 위치'),
              _buildLocationPicker(
                locationName: _startLocationName,
                onTap: () => _selectLocation(true),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('도착 위치'),
              _buildLocationPicker(
                locationName: _endLocationName,
                onTap: () => _selectLocation(false),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('시간'),
              Column(
                children: [
                  Slider(
                    value: _selectedMinutes,
                    min: 0,
                    max: 180,
                    divisions: 12,
                    label: _formatDuration(_selectedMinutes),
                    onChanged: (value) {
                      setState(() {
                        _selectedMinutes = value;
                      });
                    },
                  ),
                  Text(
                    _formatDuration(_selectedMinutes),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: themeColor),
                  )
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('LLM 세부 설정'),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: _inputDecoration(
                    'LLM이 산책로 생성을 돕기 위해 구체적인 조건을 작성해주세요!',
                    alignLabel: true),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: _buildSectionTitle('산책로 공개'),
                subtitle: const Text('다른 사용자들에게 이 산책로를 공유합니다.'),
                value: _isPublic,
                onChanged: (bool value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
                activeColor: themeColor,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetForm,
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createWalkway,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('생성하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLocationPicker(
      {required String locationName, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locationName,
                style: TextStyle(
                  color:
                      locationName.contains("선택") ? Colors.grey : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, {bool alignLabel = false}) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      alignLabelWithHint: alignLabel,
    );
  }
}
