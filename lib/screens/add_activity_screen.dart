import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final _formKey = GlobalKey<FormState>();

  // 입력 컨트롤러
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  // 선택된 데이터 상태
  String _selectedSemester = '2026-1학기';
  String _selectedCategory = '수강 과목';
  DateTime _selectedDate = DateTime.now();
  final List<String> _tags = [];
  bool _isLoading = false;

  final List<String> _semesters = ['2026-1학기', '2025-2학기', '2025-1학기', '2024-2학기'];
  final List<String> _categories = ['수강 과목', '교내 활동', '대외 활동'];

  // 날짜 선택기
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryIndigo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 태그 추가 함수
  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim());
        _tagController.clear();
      });
    }
  }

  // 데이터 저장 함수
  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firestore 'activities' 컬렉션에 데이터 추가
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': user.uid,
          'semester': _selectedSemester,
          'category': _selectedCategory,
          'title': _titleController.text,
          'content': _contentController.text,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'tags': _tags,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('활동이 성공적으로 기록되었습니다.')),
          );
          Navigator.pop(context); // 저장 후 이전 화면(활동 기록 탭)으로 복귀
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          '새 활동 기록',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          _isLoading
              ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
              : TextButton(
            onPressed: _saveActivity,
            child: Text(
              '저장',
              style: TextStyle(
                color: primaryIndigo,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 학기 및 카테고리 선택 (Dropdown)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSemester,
                      decoration: const InputDecoration(
                        labelText: '학기',
                        border: OutlineInputBorder(),
                      ),
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSemester = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '카테고리',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. 제목 입력
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '활동 제목',
                  hintText: '예) 데이터베이스 설계 프로젝트',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? '제목을 입력해주세요.' : null,
              ),
              const SizedBox(height: 24),

              // 3. 날짜 선택
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '활동 날짜',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('yyyy년 MM월 dd일').format(_selectedDate)),
                      Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. 태그 입력 (fl_chart 역량 분석에 활용될 핵심 데이터)
              TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: '역량 태그 입력',
                  hintText: '입력 후 완료(Enter)를 누르세요 (예: 리더십, Python)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle),
                    color: primaryIndigo,
                    onPressed: () => _addTag(_tagController.text),
                  ),
                ),
                onFieldSubmitted: _addTag,
              ),
              const SizedBox(height: 12),

              // 추가된 태그 리스트 시각화
              Wrap(
                spacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    backgroundColor: primaryIndigo.withOpacity(0.1),
                    labelStyle: TextStyle(color: primaryIndigo),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 5. 활동 내용 입력
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '상세 내용 및 배운 점',
                  alignLabelWithHint: true,
                  hintText: '이 활동을 통해 어떤 역할을 했고, 무엇을 배웠는지 기록해보세요.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}