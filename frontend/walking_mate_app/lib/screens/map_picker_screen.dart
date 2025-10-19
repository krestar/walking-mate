import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walking_mate_app/services/walkway_service.dart';

// 이 화면이 반환할 데이터의 형태를 정의하는 클래스
class MapPickerResult {
  final NLatLng coordinates;
  final String address;

  MapPickerResult({required this.coordinates, required this.address});
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final Completer<NaverMapController> _controllerCompleter = Completer();
  final WalkwayService _walkwayService = WalkwayService();

  // --- ✨ [수정] _initialCameraPosition을 non-nullable로 변경하고 초기값을 명확히 설정 ---
  NCameraPosition _initialCameraPosition = const NCameraPosition(
    target: NLatLng(37.5666102, 126.9783881), // 서울시청 기본값
    zoom: 16,
  );
  // --------------------------------------------------------------------------

  NLatLng? _currentMapCenter;
  String _currentAddress = "위치를 불러오는 중...";
  bool _isLoading = true;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  /// 위치 초기화 - 현재 위치를 가져오거나 기본 위치 사용
  Future<void> _initializeLocation() async {
    try {
      final position = await _getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _initialCameraPosition = NCameraPosition(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 16,
          );
        });
      }
    } catch (e) {
      debugPrint('위치 가져오기 실패: $e');
      // 실패 시 _initialCameraPosition은 이미 서울시청으로 설정되어 있음
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 현재 위치를 안전하게 가져오는 함수
  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateAddressDisplay("위치 서비스를 활성화해주세요.");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateAddressDisplay("위치 정보 접근 권한이 필요합니다.");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateAddressDisplay("설정에서 위치 정보 접근 권한을 허용해주세요.");
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _updateAddressDisplay("현재 위치를 가져올 수 없습니다.");
      return null;
    }
  }

  /// 주소 표시 업데이트 (mounted 체크 포함)
  void _updateAddressDisplay(String address) {
    if (mounted) {
      setState(() {
        _currentAddress = address;
      });
    }
  }

  /// 백엔드 API를 호출하여 주소를 가져오는 함수
  Future<void> _fetchAddress(NLatLng coordinates) async {
    try {
      final address = await _walkwayService.getAddressFromCoords(coordinates);
      _updateAddressDisplay(address);
    } catch (e) {
      debugPrint('주소 가져오기 실패: $e');
      _updateAddressDisplay("주소 변환 중 오류가 발생했습니다.");
    }
  }

  /// 카메라 위치 변경 처리
  Future<void> _handleCameraChange() async {
    if (!_isMapReady) return;

    try {
      final controller = await _controllerCompleter.future;
      final cameraPosition = await controller.getCameraPosition();
      final newCenter = cameraPosition.target;

      if (_currentMapCenter != null &&
          _isLocationSimilar(_currentMapCenter!, newCenter)) {
        return;
      }

      _updateAddressDisplay("주소 검색 중...");
      _currentMapCenter = newCenter;
      await _fetchAddress(newCenter);
    } catch (e) {
      debugPrint('카메라 변경 처리 실패: $e');
      _updateAddressDisplay("주소를 가져올 수 없습니다.");
    }
  }

  /// 두 위치가 유사한지 확인 (성능 최적화용)
  bool _isLocationSimilar(NLatLng location1, NLatLng location2) {
    const double threshold = 0.0001;
    return (location1.latitude - location2.latitude).abs() < threshold &&
        (location1.longitude - location2.longitude).abs() < threshold;
  }

  /// 현재 위치로 이동하는 함수
  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await _getCurrentPosition();
      if (position == null) return;

      final controller = await _controllerCompleter.future;
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(position.latitude, position.longitude),
        zoom: 16,
      );

      cameraUpdate.setAnimation(
        animation: NCameraAnimation.easing,
        duration: const Duration(milliseconds: 1000),
      );

      await controller.updateCamera(cameraUpdate);
    } catch (e) {
      debugPrint('현재 위치로 이동 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치로 이동할 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("위치 선택"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
            tooltip: '현재 위치로 이동',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('위치 정보를 가져오는 중...'),
                ],
              ),
            )
          : Stack(
              children: [
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition:
                        _initialCameraPosition, // non-nullable 보장
                    locationButtonEnable: false,
                    consumeSymbolTapEvents: false,
                  ),
                  onMapReady: (controller) async {
                    if (!_controllerCompleter.isCompleted) {
                      _controllerCompleter.complete(controller);
                    }

                    setState(() {
                      _isMapReady = true;
                    });

                    _currentMapCenter = _initialCameraPosition.target;
                    await _fetchAddress(_currentMapCenter!);
                  },
                  onCameraIdle: _handleCameraChange,
                ),
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _currentMapCenter != null
                                ? () {
                                    final result = MapPickerResult(
                                      coordinates: _currentMapCenter!,
                                      address: _currentAddress,
                                    );
                                    Navigator.of(context).pop(result);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3ED2B3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              "이 위치로 설정",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
