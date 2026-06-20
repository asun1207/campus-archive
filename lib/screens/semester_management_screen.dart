import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SemesterManagementScreen extends StatefulWidget {
  const SemesterManagementScreen({super.key});

  @override
  State<SemesterManagementScreen> createState() => _SemesterManagementScreenState();
}

class _SemesterManagementScreenState extends State<SemesterManagementScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- 학기 추가/수정 다이얼로그 ---
  Future<void> _showSemesterDialog({DocumentSnapshot? doc}) async {
    final TextEditingController controller = TextEditingController();
    if (doc != null) {
      controller.text = doc['name'];
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? '새 학기 추가' : '학기 수정', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '예) 2026-2학기',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: Text(doc == null ? '추가' : '수정', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    // 확인을 눌렀을 때의 Firestore 처리
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      if (doc == null) {
        // [등록] 현재 학기 개수를 파악해서 order(정렬 순서) 지정
        final snapshot = await FirebaseFirestore.instance.collection('semesters').where('userId', isEqualTo: currentUser!.uid).get();
        await FirebaseFirestore.instance.collection('semesters').add({
          'userId': currentUser!.uid,
          'name': controller.text.trim(),
          'order': snapshot.docs.length,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('새 학기가 추가되었습니다.');
      } else {
        // [수정]
        await doc.reference.update({'name': controller.text.trim()});
        _showSnackBar('학기명이 수정되었습니다.');
      }
    }
  }

  // --- 학기 삭제 다이얼로그 ---
  Future<void> _deleteSemester(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학기 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('이 학기를 삭제하면 관련 활동 기록은 유지되지만\n학기 분류에서 제외돼요.\n\n정말 삭제하시겠어요?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await doc.reference.delete();
      _showSnackBar('학기가 삭제되었습니다.');
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('학기 관리', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('semesters')
            .where('userId', isEqualTo: currentUser?.uid)
            .orderBy('order') // 생성한 순서(order)대로 정렬
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryIndigo));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
                child: Text('등록된 학기가 없습니다.\n우하단 + 버튼을 눌러 추가해보세요!',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.5)
                )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                        onPressed: () => _showSemesterDialog(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteSemester(doc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSemesterDialog(),
        backgroundColor: primaryIndigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}