import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_activity_screen.dart';
import 'semester_management_screen.dart'; // 학기 관리 화면 import

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String? _selectedSemester;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkAndCreateDefaultSemester();
  }

  // --- 최초 로그인 시 (또는 학기가 0개일 때) 기본 학기 자동 생성 ---
  Future<void> _checkAndCreateDefaultSemester() async {
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('semesters')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();

      if (snapshot.docs.isEmpty) {
        final year = DateTime.now().year;
        final term = DateTime.now().month <= 6 ? '1' : '2';
        final defaultName = '$year-$term학기';

        await FirebaseFirestore.instance.collection('semesters').add({
          'userId': currentUser!.uid,
          'name': defaultName,
          'order': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('기본 학기 생성 오류: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _navigateToAddActivity() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddActivityScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('활동 기록', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.add, color: primaryIndigo, size: 28), onPressed: _navigateToAddActivity),
        ],
      ),
      body: _isInitializing
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : _buildSemesterStream(), // 학기 데이터 스트림 렌더링
    );
  }

  // --- 1. 학기 데이터 실시간 스트림 ---
  Widget _buildSemesterStream() {
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('semesters')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('order')
          .snapshots(),
      builder: (context, semesterSnapshot) {
        if (semesterSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryIndigo));
        }

        final semesterDocs = semesterSnapshot.data?.docs ?? [];

        // 학기가 하나도 없을 때 (사용자가 다 지웠을 때)
        if (semesterDocs.isEmpty) {
          return _buildNoSemesterState();
        }

        final semesterNames = semesterDocs.map((doc) => doc['name'] as String).toList();

        // 현재 선택된 학기가 목록에 없으면(삭제됐거나 최초 진입 시) 첫 번째 학기로 갱신
        if (_selectedSemester == null || !semesterNames.contains(_selectedSemester)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedSemester = semesterNames.first);
          });
          return const SizedBox(); // 갱신 전 찰나의 순간 빈 화면
        }

        return Column(
          children: [
            _buildSemesterTabs(semesterNames),
            Expanded(child: _buildActivityStream()), // 해당 학기의 활동 데이터 불러오기
          ],
        );
      },
    );
  }

  // --- UI 컴포넌트: 학기가 없을 때 ---
  Widget _buildNoSemesterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('학기를 먼저 추가해주세요', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SemesterManagementScreen())),
            icon: const Icon(Icons.settings),
            label: const Text('학기 관리로 이동'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryIndigo, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 학기 가로 스크롤 탭 ---
  Widget _buildSemesterTabs(List<String> semesters) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: semesters.length,
        itemBuilder: (context, index) {
          final semester = semesters[index];
          final isSelected = semester == _selectedSemester;

          return GestureDetector(
            onTap: () => setState(() => _selectedSemester = semester),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryIndigo : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  semester,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 2. 해당 학기의 활동 데이터 스트림 (기존 로직과 동일) ---
  Widget _buildActivityStream() {
    if (_selectedSemester == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('semester', isEqualTo: _selectedSemester) // 동적 학기 필터링!
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryIndigo));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState();

        final classActivities = docs.where((doc) => doc['category'] == '수강 과목').toList();
        final schoolActivities = docs.where((doc) => doc['category'] == '교내 활동').toList();
        final outsideActivities = docs.where((doc) => doc['category'] == '대외 활동').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (classActivities.isNotEmpty) _buildCategorySection('📚 수강 과목', classActivities),
            if (schoolActivities.isNotEmpty) _buildCategorySection('🏫 교내 활동', schoolActivities),
            if (outsideActivities.isNotEmpty) _buildCategorySection('🌐 대외 활동', outsideActivities),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('아직 기록이 없어요', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddActivity,
            icon: const Icon(Icons.edit),
            label: const Text('기록 추가하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryIndigo, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<QueryDocumentSnapshot> activities) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('${activities.length}', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
          ...activities.map((doc) => _buildActivityCard(doc)).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddActivityScreen(activityDoc: doc)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['title'] ?? '제목 없음', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 12),
              if ((data['tags'] ?? []).isNotEmpty) ...[
                Wrap(
                  spacing: 8, runSpacing: 4,
                  children: (data['tags'] as List).map((tag) => Chip(
                    label: Text('#$tag', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    backgroundColor: Colors.grey.shade100, side: BorderSide.none, padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(data['date'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}