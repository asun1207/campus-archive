import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('역량분석')),
      body: const Center(child: Text('역량분석 화면입니다. (fl_chart 연동 예정)')),
    );
  }
}