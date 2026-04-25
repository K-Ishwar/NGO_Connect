import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'add_survey_screen.dart';

class NgoDashboard extends StatelessWidget {
  const NgoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Welcome to NGO Dashboard!'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSurveyScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Survey'),
      ),
    );
  }
}
