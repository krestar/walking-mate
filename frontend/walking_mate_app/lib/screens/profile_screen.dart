import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:walking_mate_app/screens/login_screen.dart';
import 'package:walking_mate_app/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _nicknameController = TextEditingController();

  bool _isLoading = true;
  String? _email;
  String? _profileImageUrl;
  String? _location;
  bool _discoverable = true;
  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      if (mounted) {
        setState(() {
          _nicknameController.text = userProfile['nickname'] ?? '';
          _email = userProfile['email'];
          _profileImageUrl = userProfile['profile_image_url'];
          _location = userProfile['location'];
          _discoverable = (userProfile['discoverable'] ?? 1) == 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImageFile = File(image.path);
      });
      _uploadProfileImage();
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImageFile == null) return;

    try {
      final result = await _authService.uploadProfileImage(_profileImageFile!);
      if (mounted) {
        setState(() {
          _profileImageUrl = result['imageUrl'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 이미지가 변경되었습니다.')),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    }
  }


  Future<void> _updateProfile() async {
    try {
      final data = {
        'nickname': _nicknameController.text,
        'location': _location,
        'discoverable': _discoverable,
      };
      await _authService.updateUserProfile(data);
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.')),
        );
      }
    } catch (e) {
      _handleAuthError(e);
    }
  }

  void _handleAuthError(Object e) {
    if (mounted) {
      print('### 프로필 화면 오류: $e');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showLocationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return const LocationSelectionDialog();
      },
    );

    if (result != null) {
      setState(() {
        _location = result;
      });
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('비밀번호 변경'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '현재 비밀번호'),
                  validator: (value) => value!.isEmpty ? '필수 항목입니다.' : null,
                ),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '새 비밀번호'),
                  validator: (value) => value!.isEmpty ? '필수 항목입니다.' : null,
                ),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                  validator: (value) {
                    if (value!.isEmpty) return '필수 항목입니다.';
                    if (value != newPasswordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _authService.changePassword(
                      currentPasswordController.text,
                      newPasswordController.text,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 설정'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: const Text('저장'),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _profileImageFile != null
                      ? FileImage(_profileImageFile!)
                      : (_profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : null) as ImageProvider?,
                  child: _profileImageFile == null && _profileImageUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3ED2B3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _email ?? '이메일 정보 없음',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: '닉네임',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('거주 지역'),
            subtitle: Text(_location ?? '지역을 선택해주세요.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLocationDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('워킹메이트 검색 허용'),
            subtitle: const Text('다른 사용자가 나를 검색할 수 있습니다.'),
            value: _discoverable,
            onChanged: (bool value) {
              setState(() {
                _discoverable = value;
              });
            },
            activeColor: const Color(0xFF3ED2B3),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('비밀번호 변경'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(),
          ListTile(
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.logout, color: Colors.red),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

class LocationSelectionDialog extends StatefulWidget {
  const LocationSelectionDialog({super.key});

  @override
  State<LocationSelectionDialog> createState() =>
      _LocationSelectionDialogState();
}

class _LocationSelectionDialogState extends State<LocationSelectionDialog> {
  Map<String, List<String>> _regions = {};
  List<String> _siDoList = [];
  List<String> _siGunGuList = [];

  String? _selectedSiDo;
  String? _selectedSiGunGu;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    String jsonString =
    await rootBundle.loadString('assets/korea_regions.json');
    Map<String, dynamic> jsonResponse = json.decode(jsonString);

    Map<String, List<String>> regionsData = {};
    jsonResponse.forEach((key, value) {
      if (value is List) {
        regionsData[key] = value.map((item) => item.toString()).toList();
      }
    });

    setState(() {
      _regions = regionsData;
      _siDoList = _regions.keys.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('거주 지역 선택'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('시/도 선택'),
              value: _selectedSiDo,
              items: _siDoList.map((siDo) {
                return DropdownMenuItem(
                  value: siDo,
                  child: Text(siDo),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSiDo = newValue;
                  _selectedSiGunGu = null;
                  _siGunGuList = _regions[newValue!] ?? [];
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('시/군/구 선택'),
              value: _selectedSiGunGu,
              items: _siGunGuList.map((siGunGu) {
                return DropdownMenuItem(
                  value: siGunGu,
                  child: Text(siGunGu),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSiGunGu = newValue;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: (_selectedSiDo != null && _selectedSiGunGu != null)
              ? () {
            String result = '$_selectedSiDo $_selectedSiGunGu';
            Navigator.of(context).pop(result);
          }
              : null,
          child: const Text('확인'),
        ),
      ],
    );
  }
}