import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddActivityScreen extends StatefulWidget {
  // 수정할 문서 데이터 (null이면 등록 모드, 값이 있으면 수정 모드)
  final DocumentSnapshot? activityDoc;

  const AddActivityScreen({super.key, this.activityDoc});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  String? _selectedSemester; // null 허용으로 변경
  String _selectedCategory = '수강 과목';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<String> _tags = [];
  bool _isLoading = false;
  bool _isLoadingSemesters = true; // 학기 로딩 상태 추가

  List<String> _semesters = []; // 하드코딩 리스트 삭제, 빈 배열로 시작
  final List<String> _categories = ['수강 과목', '교내 활동', '대외 활동'];

  @override
  void initState() {
    super.initState();
    _loadDynamicSemesters(); // Firestore에서 학기 목록 불러오기 실행
  }

  // --- Firestore에서 현재 유저의 학기 목록 불러오기 ---
  Future<void> _loadDynamicSemesters() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('semesters')
          .where('userId', isEqualTo: user.uid)
          .orderBy('order')
          .get();

      if (mounted) {
        setState(() {
          _semesters = snapshot.docs.map((doc) => doc['name'] as String).toList();
          if (_semesters.isEmpty) _semesters = ['기본 학기']; // 혹시 다 지웠을 때를 대비한 맹점 처리

          // 1. 수정 모드일 경우 기존 데이터로 초기값 세팅
          if (widget.activityDoc != null) {
            final data = widget.activityDoc!.data() as Map<String, dynamic>;
            _titleController.text = data['title'] ?? '';
            _contentController.text = data['content'] ?? '';
            _selectedCategory = data['category'] ?? '수강 과목';
            _selectedSemester = data['semester'];

            _startDate = DateFormat('yyyy-MM-dd').parse(data['startDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
            _endDate = DateFormat('yyyy-MM-dd').parse(data['endDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
            if (data['tags'] != null) _tags = List<String>.from(data['tags']);
          }

          // 2. _selectedSemester가 비어있거나, 삭제된 학기라면 첫 번째 학기로 강제 세팅
          if (_selectedSemester == null || !_semesters.contains(_selectedSemester)) {
            _selectedSemester = _semesters.first;
          }

          _isLoadingSemesters = false;
        });
      }
    }
  } // 👈 누락되었던 닫는 중괄호 추가 완료!

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // --- 날짜 선택기 ---
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryIndigo)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // --- 태그 추가 ---
  void _addTag(String tag) {
    // 💡 핵심: .toUpperCase()를 추가하여 무조건 대문자로 변환
    String normalizedTag = tag.trim().toUpperCase();

    // 변환된 태그를 기준으로 중복 검사 및 추가
    if (normalizedTag.isNotEmpty && !_tags.contains(normalizedTag)) {
      setState(() {
        _tags.add(normalizedTag);
        _tagController.clear();
      });
    }
  }

  // --- 스낵바 알림 ---
  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // --- 1. 저장 및 수정 로직 ---
  Future<void> _saveOrUpdateActivity() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Firestore에 넘길 데이터 맵핑
      final activityData = {
        'userId': user.uid,
        'semester': _selectedSemester,
        'category': _selectedCategory,
        'title': _titleController.text,
        'content': _contentController.text,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'tags': _tags,
        // 수정 모드면 기존 생성시간 유지, 등록 모드면 서버 시간 새로 생성
        'createdAt': widget.activityDoc != null
            ? widget.activityDoc!['createdAt']
            : FieldValue.serverTimestamp(),
      };

      if (widget.activityDoc == null) {
        // [등록 모드] 새 문서 추가 (add)
        await FirebaseFirestore.instance.collection('activities').add(activityData);
        _showSnackBar('활동이 등록됐어요!');
      } else {
        // [수정 모드] 기존 문서 업데이트 (update)
        await widget.activityDoc!.reference.update(activityData);
        _showSnackBar('수정됐어요!');
      }

      if (mounted) Navigator.pop(context); // 목록으로 복귀
    } catch (e) {
      _showSnackBar('오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. 삭제 로직 ---
  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('활동 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 삭제하시겠어요?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: Colors.black87))
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await widget.activityDoc!.reference.delete();
        _showSnackBar('삭제됐어요!');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showSnackBar('삭제 실패: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.activityDoc != null; // 전달받은 데이터가 있으면 수정 모드

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          isEditing ? '활동 수정' : '활동 등록',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: _isLoading ? null : _deleteActivity,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              label: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      // 👈 누락되었던 로딩 인디케이터 체크 로직 추가 완료!
      body: _isLoadingSemesters
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 학기 및 카테고리 (Dropdown)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSemester,
                      decoration: const InputDecoration(labelText: '학기', border: OutlineInputBorder()),
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSemester = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: '카테고리', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. 제목
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '활동 제목', hintText: '예) 데이터베이스 설계 프로젝트', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? '제목을 입력해주세요.' : null,
              ),
              const SizedBox(height: 24),

              // 3. 날짜
              InkWell(
                onTap: () => _selectDateRange(context),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '활동 기간', border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('yyyy.MM.dd').format(_startDate)} ~ ${DateFormat('yyyy.MM.dd').format(_endDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Icon(Icons.date_range, color: primaryIndigo, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. 태그
              TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: '역량 태그 입력',
                  hintText: '입력 후 완료(Enter)를 누르세요',
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

              Wrap(
                spacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    backgroundColor: primaryIndigo.withOpacity(0.1),
                    labelStyle: TextStyle(color: primaryIndigo),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 5. 내용
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '상세 내용 및 배운 점', alignLabelWithHint: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 40),

              // 하단 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveOrUpdateActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    isEditing ? '수정하기' : '등록하기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}