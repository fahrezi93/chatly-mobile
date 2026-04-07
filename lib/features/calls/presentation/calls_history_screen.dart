import 'package:flutter/material.dart';

class CallsHistoryScreen extends StatelessWidget {
  const CallsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calls')),
      body: const Center(
        child: Text('Calls History Placehoder'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_call),
      ),
    );
  }
}
