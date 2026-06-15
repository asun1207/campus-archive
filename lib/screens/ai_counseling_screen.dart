import 'package:flutter/material.dart';

class AiCounselingScreen extends StatelessWidget {
  const AiCounselingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI상담')),
      body: const Center(child: Text('AI 상담 화면입니다. (Claude API 연동 예정)')),
    );
  }
}