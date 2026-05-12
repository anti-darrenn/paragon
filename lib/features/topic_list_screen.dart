import 'package:flutter/material.dart';

class TopicListScreen extends StatelessWidget {
  const TopicListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paragon')),
      body: const Center(child: Text('Topic List')),
    );
  }
}