import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DbSeeder {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> wipeAndSeed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Starting Database Wipe & Seed...')));
      
      // 1. Wipe Collections
      final collections = [
        'users', 'camps', 'camp_assignments', 'surveys', 
        'survey_responses', 'tasks', 'feedback', 'notifications'
      ];
      
      for (final col in collections) {
        final snap = await _db.collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }

      messenger.showSnackBar(const SnackBar(content: Text('Collections wiped. Creating users...')));

      // 2. Create Users
      final usersData = [
        // NGOs
        {
          'email': 'mumbai_ngo@demo.com', 'name': 'Mumbai Relief Foundation', 
          'role': 'ngo', 'location': 'Mumbai', 'registration_number': 'MUM12345', 'focus_area': 'Disaster Relief'
        },
        {
          'email': 'mumbai_ngo2@demo.com', 'name': 'Dharavi Education Initiative', 
          'role': 'ngo', 'location': 'Dharavi, Mumbai', 'registration_number': 'MUM98765', 'focus_area': 'Education'
        },
        {
          'email': 'pune_ngo@demo.com', 'name': 'Pune Social Initiative', 
          'role': 'ngo', 'location': 'Pune', 'registration_number': 'PUN11223', 'focus_area': 'Community Support'
        },
        {
          'email': 'pune_ngo2@demo.com', 'name': 'Kothrud Green Earth', 
          'role': 'ngo', 'location': 'Kothrud, Pune', 'registration_number': 'PUN44556', 'focus_area': 'Environment'
        },
        // Volunteers
        {
          'email': 'ravi_vol@demo.com', 'name': 'Ravi Sharma', 'role': 'volunteer',
          'location': 'Andheri, Mumbai', 'skills': 'Medical, Logistics', 'phone_number': '9876543210', 'availability': 'part-time', 'experience_years': 3
        },
        {
          'email': 'sneha_vol@demo.com', 'name': 'Sneha Patel', 'role': 'volunteer',
          'location': 'Bandra, Mumbai', 'skills': 'Education, Teaching', 'phone_number': '9876543211', 'availability': 'full-time', 'experience_years': 2
        },
        {
          'email': 'priya_vol@demo.com', 'name': 'Priya Deshmukh', 'role': 'volunteer',
          'location': 'Katraj, Pune', 'skills': 'Tech Education, Public Speaking', 'phone_number': '9876543212', 'availability': 'part-time', 'experience_years': 1
        },
        {
          'email': 'amit_vol@demo.com', 'name': 'Amit Joshi', 'role': 'volunteer',
          'location': 'Viman Nagar, Pune', 'skills': 'Logistics, Support', 'phone_number': '9876543213', 'availability': 'weekend', 'experience_years': 4
        },
      ];

      Map<String, String> uidMap = {}; // mapping email to UID

      for (final u in usersData) {
        String uid = '';
        try {
          final cred = await _auth.createUserWithEmailAndPassword(email: u['email'] as String, password: 'demo123');
          uid = cred.user!.uid;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            final cred = await _auth.signInWithEmailAndPassword(email: u['email'] as String, password: 'demo123');
            uid = cred.user!.uid;
          } else {
            throw e;
          }
        }
        
        uidMap[u['email'] as String] = uid;

        // Save to Firestore users collection
        final docData = Map<String, dynamic>.from(u);
        docData.remove('email'); // keep clean
        docData['email'] = u['email'];
        docData['created_at'] = FieldValue.serverTimestamp();
        
        await _db.collection('users').doc(uid).set(docData);
      }

      messenger.showSnackBar(const SnackBar(content: Text('Users created. Seeding data...')));

      // 3. Seed Mumbai Data
      final mumbaiNgoId = uidMap['mumbai_ngo@demo.com']!;
      
      final mumbaiSurveyRef = await _db.collection('surveys').add({
        'submitted_by': mumbaiNgoId,
        'area': 'Andheri East Slums, Mumbai',
        'problem_type': 'Infrastructure',
        'people_count': 500,
        'urgency': 'High',
        'description': 'Severe water logging and sanitation issues. Need immediate medical and logistical support.',
        'date': Timestamp.now(),
        'image_url': '',
        'assigned_to': '',
        'status': 'pending',
      });

      final mumbaiCampRef = await _db.collection('camps').add({
        'ngo_id': mumbaiNgoId,
        'name': 'Monsoon Medical & Relief Drive',
        'location': 'Andheri East, Mumbai',
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
        'description': 'Providing urgent medical care and logistical support for waterlogged areas.',
        'volunteers_required': 5,
        'skills_needed': ['Medical', 'Logistics'],
        'status': 'upcoming',
        'created_at': Timestamp.now(),
      });

      // 4. Seed Pune Data
      final puneNgoId = uidMap['pune_ngo@demo.com']!;
      final puneSurveyRef = await _db.collection('surveys').add({
        'submitted_by': puneNgoId,
        'area': 'Katraj, Pune',
        'problem_type': 'Education',
        'people_count': 150,
        'urgency': 'Medium',
        'description': 'Lack of basic digital literacy among elderly and underprivileged youth.',
        'date': Timestamp.now(),
        'image_url': '',
        'assigned_to': '',
        'status': 'pending',
      });

      final puneCampRef = await _db.collection('camps').add({
        'ngo_id': puneNgoId,
        'name': 'Katraj Digital Saathi Workshop',
        'location': 'Katraj, Pune',
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
        'description': 'A 2-day workshop to teach basic smartphone and internet usage.',
        'volunteers_required': 3,
        'skills_needed': ['Tech Education', 'Teaching', 'Public Speaking'],
        'status': 'upcoming',
        'created_at': Timestamp.now(),
      });

      // 5. Seed Feedback (Historical data for graphs)
      await _db.collection('feedback').add({
        'ngo_id': mumbaiNgoId,
        'survey_id': 'historical_mumbai_1',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10))),
        'people_helped': 450,
        'remaining_need': 'Clean drinking water',
        'comments': 'Relief drive was successful but water supply remains a critical issue.',
      });

      await _db.collection('feedback').add({
        'ngo_id': puneNgoId,
        'survey_id': 'historical_pune_1',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 20))),
        'people_helped': 120,
        'remaining_need': 'Advanced Computer classes',
        'comments': 'Students loved the basics, requested advanced Excel training next.',
      });

      // Sign out so user can log in manually for the demo
      await _auth.signOut();

      messenger.showSnackBar(const SnackBar(
        content: Text('✅ Seeding Complete! Please login with the demo accounts.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ));

    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}
