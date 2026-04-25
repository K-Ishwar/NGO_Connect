import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/survey_model.dart';
import '../services/survey_service.dart';

class AddSurveyScreen extends StatefulWidget {
  const AddSurveyScreen({super.key});

  @override
  State<AddSurveyScreen> createState() => _AddSurveyScreenState();
}

class _AddSurveyScreenState extends State<AddSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _areaController = TextEditingController();
  final _peopleCountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedProblemType = 'Food';
  String _selectedUrgency = 'Medium';
  bool _isLoading = false;

  final List<String> _problemTypes = ['Food', 'Health', 'Jobs', 'Education', 'Other'];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Not logged in.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final newSurvey = SurveyModel(
      ngoId: currentUser.uid,
      area: _areaController.text.trim(),
      problemType: _selectedProblemType,
      peopleCount: int.parse(_peopleCountController.text.trim()),
      urgency: _selectedUrgency,
      description: _descriptionController.text.trim(),
      date: DateTime.now(),
    );

    final success = await SurveyService().addSurvey(newSurvey);
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey submitted successfully!')),
      );
      Navigator.pop(context); // Go back to dashboard
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit survey. Try again.')),
      );
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _peopleCountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Survey Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area'),
                validator: (value) => 
                  value == null || value.isEmpty ? 'Area is required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedProblemType,
                items: _problemTypes.map((type) => 
                  DropdownMenuItem(value: type, child: Text(type))
                ).toList(),
                onChanged: (val) => setState(() => _selectedProblemType = val!),
                decoration: const InputDecoration(labelText: 'Problem Type'),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _peopleCountController,
                decoration: const InputDecoration(labelText: 'Number of People Affected'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedUrgency,
                items: _urgencyLevels.map((level) => 
                  DropdownMenuItem(value: level, child: Text(level))
                ).toList(),
                onChanged: (val) => setState(() => _selectedUrgency = val!),
                decoration: const InputDecoration(labelText: 'Urgency'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => 
                  value == null || value.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 32),

              _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    onPressed: _submitFeedback,
                    child: const Text('Submit Data'),
                  )
            ],
          ),
        ),
      ),
    );
  }
}
