import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/camp_model.dart';
import '../models/camp_assignment_model.dart';
import '../models/user_model.dart';

class CampService {
  final _db = FirebaseFirestore.instance;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String?> createCamp(CampModel camp) async {
    try {
      final doc = await _db.collection('camps').add(camp.toMap());
      return doc.id;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCampStatus(String campId, String status) async {
    try {
      await _db.collection('camps').doc(campId).update({'status': status});
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<CampModel>> streamCampsForNgo(String ngoId) {
    return _db
        .collection('camps')
        .where('ngo_id', isEqualTo: ngoId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => CampModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Assignment ────────────────────────────────────────────────────────────

  /// 4-factor smart matching: Location(30%) + Skills(35%) + Availability(20%) + Experience(15%)
  Future<String> autoAssignCamp(CampModel camp) async {
    try {
      final volunteersSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();

      if (volunteersSnap.docs.isEmpty) return 'No volunteers registered.';

      // Get already-assigned volunteer IDs for this camp
      final existingSnap = await _db
          .collection('camp_assignments')
          .where('camp_id', isEqualTo: camp.id)
          .get();
      final assignedIds = existingSnap.docs.map((d) => d['volunteer_id'] as String).toSet();

      final campArea = camp.area.toLowerCase();
      final campSkills = camp.skillsNeeded.map((s) => s.toLowerCase()).toList();

      final List<Map<String, dynamic>> scored = [];

      for (final doc in volunteersSnap.docs) {
        final data = doc.data();
        final uid = doc.id;
        if (assignedIds.contains(uid)) continue;

        final volArea = (data['location'] ?? '').toString().toLowerCase();
        final volSkills = List<String>.from(data['skills'] ?? []).map((s) => s.toLowerCase()).toList();
        final volAvailability = (data['availability'] ?? 'part-time').toString().toLowerCase();
        final volExperience = (data['experience_years'] as num?)?.toInt() ?? 0;

        // Location score (30%)
        int locationScore = 0;
        if (campArea.contains(volArea) || volArea.contains(campArea)) locationScore = 30;
        else if (_shareWords(campArea, volArea)) locationScore = 15;

        // Skills score (35%)
        int skillScore = 0;
        if (campSkills.isNotEmpty) {
          int matched = 0;
          for (final vs in volSkills) {
            if (campSkills.any((cs) => cs.contains(vs) || vs.contains(cs))) matched++;
          }
          skillScore = ((matched / campSkills.length) * 35).round().clamp(0, 35);
        } else {
          skillScore = 17; // No skill requirement = partial score for all
        }

        // Availability score (20%)
        int availScore = volAvailability == 'full-time' ? 20 : 10;

        // Experience score (15%)
        int expScore = (volExperience >= 3 ? 15 : volExperience >= 1 ? 10 : 5);

        final total = locationScore + skillScore + availScore + expScore;
        scored.add({'uid': uid, 'data': data, 'score': total});
      }

      if (scored.isEmpty) return 'All available volunteers already assigned.';

      // Sort by score descending
      scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      // Assign top N volunteers (up to volunteersRequired)
      int toAssign = camp.volunteersRequired - assignedIds.length;
      toAssign = toAssign.clamp(1, scored.length);
      int assigned = 0;

      for (int i = 0; i < toAssign; i++) {
        final v = scored[i];
        final uid = v['uid'] as String;
        final score = v['score'] as int;

        final assignment = CampAssignmentModel(
          campId: camp.id!,
          volunteerId: uid,
          role: _inferRole(camp.skillsNeeded, List<String>.from((v['data'] as Map)['skills'] ?? [])),
          status: 'assigned',
          matchScore: score,
        );
        await _db.collection('camp_assignments').add(assignment.toMap());

        // Notify the volunteer
        await _db.collection('notifications').add({
          'user_id': uid,
          'title': 'Camp Assignment — ${camp.campName}',
          'body': 'You have been assigned to "${camp.campName}" on ${camp.scheduledDate.toString().split(' ').first} at ${camp.area}. Match score: $score%.',
          'date': Timestamp.now(),
          'type': 'camp_assignment',
        });
        assigned++;
      }

      return 'Successfully assigned $assigned volunteer${assigned > 1 ? 's' : ''} to this camp!';
    } catch (e) {
      return 'Error during assignment: $e';
    }
  }

  Future<bool> manualAssignCamp({
    required String campId,
    required String volunteerId,
    required String role,
  }) async {
    try {
      final assignment = CampAssignmentModel(
        campId: campId,
        volunteerId: volunteerId,
        role: role,
        status: 'assigned',
        matchScore: 50,
      );
      await _db.collection('camp_assignments').add(assignment.toMap());

      // Update volunteer notification
      final campDoc = await _db.collection('camps').doc(campId).get();
      final campData = campDoc.data();
      final campName = campData?['camp_name'] ?? 'Camp';
      final campDate = (campData?['scheduled_date'] as Timestamp?)?.toDate().toString().split(' ').first ?? '';

      await _db.collection('notifications').add({
        'user_id': volunteerId,
        'title': 'Camp Assignment — $campName',
        'body': 'You have been manually assigned to "$campName" on $campDate.',
        'date': Timestamp.now(),
        'type': 'camp_assignment',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<CampAssignmentModel>> streamAssignmentsForCamp(String campId) {
    return _db
        .collection('camp_assignments')
        .where('camp_id', isEqualTo: campId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CampAssignmentModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Get all camp assignments for a specific volunteer (returns CampAssignmentModel)
  Stream<List<CampAssignmentModel>> streamCampsForVolunteer(String volunteerId) {
    return _db
        .collection('camp_assignments')
        .where('volunteer_id', isEqualTo: volunteerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CampAssignmentModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Resolve camp assignments → full CampModel list for volunteer dashboard
  Stream<List<CampModel>> streamCampModelsForVolunteer(String volunteerId) {
    return _db
        .collection('camp_assignments')
        .where('volunteer_id', isEqualTo: volunteerId)
        .snapshots()
        .asyncMap((snap) async {
      final List<CampModel> camps = [];
      for (final doc in snap.docs) {
        final campId = doc.data()['camp_id'] as String? ?? '';
        if (campId.isEmpty) continue;
        final campDoc = await _db.collection('camps').doc(campId).get();
        if (campDoc.exists) {
          camps.add(CampModel.fromMap(campDoc.data()!, campDoc.id));
        }
      }
      return camps;
    });
  }

  Future<bool> updateAssignmentStatus(String assignmentId, String status) async {
    try {
      await _db.collection('camp_assignments').doc(assignmentId).update({'status': status});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _shareWords(String a, String b) {
    final wordsA = a.split(RegExp(r'\s+'));
    final wordsB = b.split(RegExp(r'\s+'));
    return wordsA.any((w) => w.length > 2 && wordsB.contains(w));
  }

  String _inferRole(List<String> campSkills, List<String> volSkills) {
    final volSkillsLower = volSkills.map((s) => s.toLowerCase()).toList();
    if (volSkillsLower.any((s) => s.contains('doctor') || s.contains('medical') || s.contains('nurse'))) {
      return 'Medical Staff';
    }
    if (volSkillsLower.any((s) => s.contains('logistics') || s.contains('transport'))) {
      return 'Logistics';
    }
    if (volSkillsLower.any((s) => s.contains('coordinator') || s.contains('manage'))) {
      return 'Coordinator';
    }
    return 'General Volunteer';
  }

  /// Fetch UserModel for a volunteer
  Future<UserModel?> getVolunteer(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return UserModel.fromMap(doc.data()!, uid);
      return null;
    } catch (_) {
      return null;
    }
  }
}
