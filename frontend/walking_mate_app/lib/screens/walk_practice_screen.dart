import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walking_mate_app/models/walkway_model.dart';
import 'package:walking_mate_app/screens/walk_result_screen.dart';
import 'package:walking_mate_app/services/walkrecord_service.dart';

class WalkPracticeScreen extends StatefulWidget {
  final Walkway walkway;

  const WalkPracticeScreen({required this.walkway, super.key});

  @override
  State<WalkPracticeScreen> createState() => _WalkPracticeScreenState();
}

class _WalkPracticeScreenState extends State<WalkPracticeScreen> {
  final Completer<NaverMapController> _mapControllerCompleter = Completer();
  StreamSubscription<Position>? _positionStream;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isPaused = false;
  String _elapsedTime = "00:00:00";

  Position? _currentPosition;
  double _totalDistanceWalked = 0.0;
  double _remainingDistance = 0.0;
  int _remainingTime = 0;
  bool _isFinishing = false;

  List<NLatLng> _originalPathCoords = [];
  List<NLatLng> _walkedPathCoords = [];
  List<NLatLng> _remainingPathCoords = [];

  @override
  void initState() {
    super.initState();
    _originalPathCoords =
        widget.walkway.pathData.map((p) => NLatLng(p[1], p[0])).toList();
    _remainingPathCoords = List.from(_originalPathCoords);
    _startWalking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startWalking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    _remainingDistance = widget.walkway.distance ?? 0.0;
    _remainingTime = widget.walkway.estimatedTime ?? 0;
    _stopwatch.start();
    _startTimer();

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = initialPosition;
      await _updateMapAndInfo(isInitial: true);
    } catch (e) {
      print("초기 위치를 가져오는 데 실패했습니다: $e");
    }

    _startLocationTracking();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        final elapsed = _stopwatch.elapsed;
        if (mounted) {
          setState(() {
            _elapsedTime =
                '${(elapsed.inHours).toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
          });
        }
      }
    });
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (_isPaused || !mounted) return;

      if (_currentPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistanceWalked += distanceInMeters / 1000.0;
      }
      _currentPosition = position;
      _updateMapAndInfo();
    });
  }

  Future<void> _updateMapAndInfo({bool isInitial = false}) async {
    if (_currentPosition == null) return;

    final controller = await _mapControllerCompleter.future;

    final userMarker = NMarker(
      id: 'user',
      position:
          NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: const NOverlayImage.fromAssetImage('assets/icons/ic_walking.svg'),
      size: const Size(40, 40),
    );
    controller.addOverlay(userMarker);

    if (isInitial || _stopwatch.elapsed.inSeconds % 2 == 0) {
      controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target:
              NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 16,
        ),
      );
    }

    _calculateRemainingDistance();
    _updatePathOverlays(controller);

    if (mounted) {
      setState(() {});
    }
  }

  void _calculateRemainingDistance() {
    double newRemainingDistance =
        (widget.walkway.distance ?? 0.0) - _totalDistanceWalked;
    _remainingDistance = newRemainingDistance > 0 ? newRemainingDistance : 0;
    _remainingTime = ((_remainingDistance / 4.5) * 60).round();
  }

  void _updatePathOverlays(NaverMapController controller) {
    if (_currentPosition == null || _originalPathCoords.isEmpty) return;

    int closestIndex = -1;
    double minDistance = double.infinity;
    for (int i = 0; i < _originalPathCoords.length; i++) {
      final coord = _originalPathCoords[i];
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        coord.latitude,
        coord.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != -1) {
      setState(() {
        _walkedPathCoords = _originalPathCoords.sublist(0, closestIndex + 1);
        _remainingPathCoords = _originalPathCoords.sublist(closestIndex);
      });
    }

    final walkedPathOverlay = NPathOverlay(
      id: 'walked_path',
      coords: _walkedPathCoords,
      color: Colors.grey.withOpacity(0.8),
      width: 6,
    );
    final remainingPathOverlay = NPathOverlay(
      id: 'remaining_path',
      coords: _remainingPathCoords,
      color: const Color(0xFF3ED2B3),
      width: 6,
    );
    controller.addOverlayAll({walkedPathOverlay, remainingPathOverlay});
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
    });
  }

  void _finishWalking() async {
    if (_isFinishing) return;
    setState(() {
      _isFinishing = true;
    });

    _stopwatch.stop();
    _timer?.cancel();
    _positionStream?.cancel();

    final totalTimeInSeconds = _stopwatch.elapsed.inSeconds;

    try {
      // --- 🚀 [수정] 반환된 값을 resultData에 저장 ---
      final resultData = await WalkRecordService().saveWalkRecord(
        widget.walkway.walkwayId,
        totalTimeInSeconds,
        _totalDistanceWalked,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WalkResultScreen(
              totalTime: totalTimeInSeconds,
              totalDistance: _totalDistanceWalked,
              resultData: resultData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록 저장 실패: $e')),
        );
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final controller = await _mapControllerCompleter.future;
      controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(position.latitude, position.longitude),
          zoom: 16,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('현재 위치를 가져올 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _moveToCurrentLocation,
            icon: const Icon(Icons.my_location),
            color: Colors.black,
            tooltip: '현재 위치로 이동',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              mapType: NMapType.basic,
              locationButtonEnable: false,
              extent: NLatLngBounds(
                southWest: NLatLng(31.43, 122.37),
                northEast: NLatLng(44.35, 132),
              ),
            ),
            onMapReady: (controller) {
              _mapControllerCompleter.complete(controller);
              final remainingPathOverlay = NPathOverlay(
                id: 'remaining_path',
                coords: _remainingPathCoords,
                color: const Color(0xFF3ED2B3),
                width: 6,
              );
              controller.addOverlay(remainingPathOverlay);

              if (_remainingPathCoords.isNotEmpty) {
                final bounds = NLatLngBounds.from(_remainingPathCoords);
                controller.updateCamera(NCameraUpdate.fitBounds(bounds,
                    padding: const EdgeInsets.all(100)));
              }
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF3ED2B3),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      )
                    ]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _elapsedTime,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoBox(
                        "남은 거리", "${_remainingDistance.toStringAsFixed(2)} KM"),
                    _buildInfoBox("남은 시간", "$_remainingTime 분"),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _togglePause,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPaused
                              ? const Color(0xFF3ED2B3)
                              : Colors.white,
                          foregroundColor:
                              _isPaused ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(_isPaused ? "다시 시작" : "일시정지"),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isFinishing ? null : _finishWalking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isFinishing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("산책 종료하기"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3ED2B3),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
