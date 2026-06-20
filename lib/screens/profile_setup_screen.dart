import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing; // true: 마이페이지에서 수정, false: 최초 가입 시 설정
  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _dreamController = TextEditingController(); // 💡 꿈 입력용 컨트롤러 추가

  List<Map<String, dynamic>> _majorFields = [];

  String _selectedGrade = '1학년';
  final List<String> _grades = ['1학년', '2학년', '3학년', '4학년', '5학년', '초과 학기', '졸업생'];
  final List<String> _majorTypes = ['주전공', '복수전공', '부전공', '융합전공', '연계전공'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingProfile();
    } else {
      _addNewMajorField(type: '주전공');
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _dreamController.dispose(); // 💡 해제 규칙 추가
    for (var field in _majorFields) {
      field['controller'].dispose();
    }
    super.dispose();
  }

  void _addNewMajorField({String type = '주전공', String name = ''}) {
    setState(() {
      _majorFields.add({
        'type': type,
        'controller': TextEditingController(text: name),
      });
    });
  }

  void _removeMajorField(int index) {
    if (_majorFields.length > 1) {
      setState(() {
        _majorFields[index]['controller'].dispose();
        _majorFields.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 하나의 전공은 입력해야 합니다.')),
      );
    }
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _schoolController.text = data['school'] ?? '';
            _dreamController.text = data['dream'] ?? ''; // 💡 기존 저장된 꿈 불러오기
            _selectedGrade = _grades.contains(data['grade']) ? data['grade'] : '1학년';

            final List<dynamic>? savedMajors = data['majors'];
            if (savedMajors != null && savedMajors.isNotEmpty) {
              _majorFields.clear();
              for (var m in savedMajors) {
                _addNewMajorField(type: m['type'] ?? '주전공', name: m['name'] ?? '');
              }
            } else {
              _addNewMajorField(type: '주전공');
            }
          });
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        List<Map<String, String>> majorsData = _majorFields.map((field) {
          return {
            'type': field['type'] as String,
            'name': (field['controller'] as TextEditingController).text.trim(),
          };
        }).toList();

        // 💡 Firestore에 dream 필드 병합 저장
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'school': _schoolController.text.trim(),
          'majors': majorsData,
          'grade': _selectedGrade,
          'dream': _dreamController.text.trim(), // 👈 꿈 한 줄 저장
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isEditing,
      onPopInvoked: (didPop) {
        if (!didPop && !widget.isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초기 프로필 설정을 완료해주세요!')));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Text(widget.isEditing ? '프로필 수정' : '프로필 설정', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          automaticallyImplyLeading: widget.isEditing,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isEditing) ...[
                  Text('반가워요! 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryIndigo)),
                  const SizedBox(height: 8),
                  const Text('Campus Archive를 시작하기 전에\n기본 정보를 입력해주세요.', style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4)),
                  const SizedBox(height: 32),
                ],

                // 1. 학교명
                const Text('학교명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _schoolController,
                  decoration: const InputDecoration(hintText: '예) 한국대학교', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? '학교명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 32),

                // 2. 동적 전공 입력 섹션
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('전공 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    TextButton.icon(
                      onPressed: () => _addNewMajorField(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('전공 추가', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: primaryIndigo),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ..._majorFields.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var field = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            value: field['type'],
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                            items: _majorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => field['type'] = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: field['controller'],
                            decoration: const InputDecoration(hintText: '학과명 입력', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                            validator: (val) => val == null || val.trim().isEmpty ? '학과명을 입력해주세요.' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _removeMajorField(idx),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),

                // 3. 현재 학년/상태 (드롭다운)
                const Text('현재 상태', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGrade,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _selectedGrade = val!),
                ),
                const SizedBox(height: 32),

                // 4. 💡 [신규] 나의 꿈 / 동기부여 섹션 추가
                const Text('나의 꿈 / 목표 (동기부여)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dreamController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '예) 세상에 선한 영향력을 끼치는 AI 서비스 기획자 개발하기!',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  // 꿈은 선택 사항이므로 validator 생략 (적고 싶을 때만 기록)
                ),
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryIndigo, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.isEditing ? '수정하기' : '시작하기', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}