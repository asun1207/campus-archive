import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_activity_screen.dart';
import 'semester_management_screen.dart';

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

  Future<void> _checkAndCreateDefaultSemester() async {
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('semesters').where('userId', isEqualTo: currentUser!.uid).get();
      if (snapshot.docs.isEmpty) {
        final year = DateTime.now().year;
        final term = DateTime.now().month <= 6 ? '1' : '2';
        await FirebaseFirestore.instance.collection('semesters').add({
          'userId': currentUser!.uid,
          'name': '$year-$term학기',
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
      // 💡 1. backgroundColor 삭제: main.dart의 부드러운 연보라 회색 배경을 그대로 흡수함
      appBar: AppBar(
        // 💡 2. AppBar의 backgroundColor 삭제
        title: const Text('활동 기록'),
        actions: [
          IconButton(icon: Icon(Icons.add_circle_outline, color: primaryIndigo, size: 28), onPressed: _navigateToAddActivity),
          const SizedBox(width: 8),
        ],
      ),
      body: _isInitializing
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : _buildSemesterStream(),
    );
  }

  Widget _buildSemesterStream() {
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('semesters').where('userId', isEqualTo: currentUser!.uid).orderBy('order').snapshots(),
      builder: (context, semesterSnapshot) {
        if (semesterSnapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryIndigo));
        final semesterDocs = semesterSnapshot.data?.docs ?? [];
        if (semesterDocs.isEmpty) return _buildNoSemesterState();

        final semesterNames = semesterDocs.map((doc) => doc['name'] as String).toList();
        if (_selectedSemester == null || !semesterNames.contains(_selectedSemester)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedSemester = semesterNames.first);
          });
          return const SizedBox();
        }

        return Column(
          children: [
            _buildSemesterTabs(semesterNames),
            const SizedBox(height: 8),
            Expanded(child: _buildActivityStream()),
          ],
        );
      },
    );
  }

  Widget _buildNoSemesterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('학기를 먼저 추가해주세요', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SemesterManagementScreen())),
            icon: const Icon(Icons.settings),
            label: const Text('학기 관리로 이동'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryIndigo, foregroundColor: Colors.white,
              elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSemesterTabs(List<String> semesters) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: semesters.length,
        itemBuilder: (context, index) {
          final semester = semesters[index];
          final isSelected = semester == _selectedSemester;

          return GestureDetector(
            onTap: () => setState(() => _selectedSemester = semester),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                    : [],
                border: isSelected ? null : Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  semester,
                  style: TextStyle(
                    color: isSelected ? primaryIndigo : Colors.grey.shade600,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityStream() {
    if (_selectedSemester == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activities').where('userId', isEqualTo: currentUser!.uid).where('semester', isEqualTo: _selectedSemester).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryIndigo));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState();

        final classActivities = docs.where((doc) => doc['category'] == '수강 과목').toList();
        final schoolActivities = docs.where((doc) => doc['category'] == '교내 활동').toList();
        final outsideActivities = docs.where((doc) => doc['category'] == '대외 활동').toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const Text('아직 기록이 없어요', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddActivity,
            icon: const Icon(Icons.edit),
            label: const Text('기록 추가하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryIndigo, foregroundColor: Colors.white,
              elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<QueryDocumentSnapshot> activities) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('${activities.length}', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          ...activities.map((doc) => _buildModernActivityCard(doc)).toList(),
        ],
      ),
    );
  }

  // 💡 3. SaaS 스타일의 새로운 모던 카드 컴포넌트 적용!
  Widget _buildModernActivityCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: primaryIndigo.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddActivityScreen(activityDoc: doc))),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '제목 없음', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B), letterSpacing: -0.3)),
                const SizedBox(height: 12),
                if (tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: primaryIndigo.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                      child: Text('#$tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryIndigo)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(data['date'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}