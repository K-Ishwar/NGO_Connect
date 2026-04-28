import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/camp_model.dart';
import '../models/camp_assignment_model.dart';
import '../services/camp_service.dart';

class CampDetailScreen extends StatefulWidget {
  final CampModel camp;

  const CampDetailScreen({super.key, required this.camp});

  @override
  State<CampDetailScreen> createState() => _CampDetailScreenState();
}

class _CampDetailScreenState extends State<CampDetailScreen> {
  final Color baseColor = const Color(0xFFF2F2F2);
  final _campService = CampService();
  bool _isAssigning = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'planned': return Colors.orange;
      case 'active': return Colors.green;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'planned': return Icons.schedule;
      case 'active': return Icons.play_arrow;
      case 'completed': return Icons.check_circle;
      default: return Icons.circle;
    }
  }

  Future<void> _autoAssign() async {
    setState(() => _isAssigning = true);
    final result = await _campService.autoAssignCamp(widget.camp);
    if (!mounted) return;
    setState(() => _isAssigning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
        backgroundColor: result.startsWith('Successfully') ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showManualAssignDialog() async {
    final volunteersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .get();

    if (!mounted) return;

    String? selectedId;
    String selectedRole = 'General Volunteer';
    final roles = ['Medical Staff', 'Coordinator', 'Logistics', 'General Volunteer'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Manual Assign Volunteer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Volunteer:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...volunteersSnap.docs.map((doc) {
                  final data = doc.data();
                  final name = data['name'] ?? 'Unknown';
                  final location = data['location'] ?? '';
                  final skills = List<String>.from(data['skills'] ?? []).join(', ');
                  return RadioListTile<String>(
                    dense: true,
                    value: doc.id,
                    groupValue: selectedId,
                    onChanged: (v) => setS(() => selectedId = v),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('📍 $location\n🎯 $skills', style: const TextStyle(fontSize: 11)),
                  );
                }),
                const SizedBox(height: 16),
                const Text('Assign Role:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setS(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null ? null : () async {
                Navigator.pop(ctx);
                final ok = await _campService.manualAssignCamp(
                  campId: widget.camp.id!,
                  volunteerId: selectedId!,
                  role: selectedRole,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Volunteer assigned!' : 'Assignment failed.'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8A2387)),
              child: const Text('Assign', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    await _campService.updateCampStatus(widget.camp.id!, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camp marked as $newStatus'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _whatsAppNotify(String? phone, String volunteerName) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this volunteer.')),
      );
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final date = DateFormat('dd MMM yyyy').format(widget.camp.scheduledDate);
    final msg = Uri.encodeComponent(
      'Hello $volunteerName! 🎗️\n\nYou have been assigned to "${widget.camp.campName}" at ${widget.camp.area} on $date.\n\nPlease confirm your availability. Thank you!',
    );
    final url = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final camp = widget.camp;
    final dateStr = DateFormat('dd MMM yyyy').format(camp.scheduledDate);

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: Text(camp.campName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateStatus,
            icon: const Icon(Icons.more_vert, color: Color(0xFF8A2387)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'planned', child: Text('Mark as Planned')),
              const PopupMenuItem(value: 'active', child: Text('Mark as Active')),
              const PopupMenuItem(value: 'completed', child: Text('Mark as Completed')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Camp Header ────────────────────────────────────
            ClayContainer(
              color: baseColor, borderRadius: 16, depth: 20,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5F72BD), Color(0xFF8A2387)],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(camp.campName,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(_statusIcon(camp.status), color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(camp.status.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('🏥 ${camp.campType}  •  📍 ${camp.location.isNotEmpty ? camp.location : camp.area}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('📅 $dateStr',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    if (camp.aiRecommendation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(camp.aiRecommendation,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats Row ──────────────────────────────────────
            Row(
              children: [
                Expanded(child: _statCard('Target', camp.targetBeneficiaries.toString(), Icons.people, Colors.blueAccent)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Volunteers\nNeeded', camp.volunteersRequired.toString(), Icons.group, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Resources Needed ───────────────────────────────
            if (camp.resourcesNeeded.isNotEmpty) ...[
              _sectionLabel('📦 Resources Needed', Colors.deepOrange),
              const SizedBox(height: 8),
              ClayContainer(
                color: baseColor, borderRadius: 14, depth: 14,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: camp.resourcesNeeded.map((r) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Text(r, style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
                      )
                    ).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Skills Needed ──────────────────────────────────
            if (camp.skillsNeeded.isNotEmpty) ...[
              _sectionLabel('🎯 Skills Needed', Colors.purple),
              const SizedBox(height: 8),
              ClayContainer(
                color: baseColor, borderRadius: 14, depth: 14,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: camp.skillsNeeded.map((s) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600)),
                      )
                    ).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Volunteer Assignment ───────────────────────────
            _sectionLabel('👥 Volunteer Assignment', const Color(0xFF8A2387)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isAssigning ? null : _autoAssign,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: const Color(0xFFE94057).withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 6),
                        )],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isAssigning
                          ? const Center(child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Column(children: [
                              Icon(Icons.auto_awesome, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Smart Auto-Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showManualAssignDialog,
                    child: ClayContainer(
                      color: baseColor, borderRadius: 14, depth: 20,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(children: [
                          Icon(Icons.person_add, color: Color(0xFF8A2387)),
                          SizedBox(height: 4),
                          Text('Manual Assign', style: TextStyle(color: Color(0xFF8A2387), fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Assigned Volunteers List ───────────────────────
            _sectionLabel('📋 Assigned Volunteers', Colors.green),
            const SizedBox(height: 10),
            StreamBuilder<List<CampAssignmentModel>>(
              stream: _campService.streamAssignmentsForCamp(camp.id!),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return ClayContainer(
                    color: baseColor, borderRadius: 12, depth: -10,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text('No volunteers assigned yet.\nUse Smart Auto-Assign or Manual Assign above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      ),
                    ),
                  );
                }

                final assignments = snap.data!;
                return Column(
                  children: assignments.map((assignment) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users').doc(assignment.volunteerId).get(),
                        builder: (context, userSnap) {
                          String name = 'Loading...';
                          String phone = '';
                          String location = '';
                          String skills = '';
                          if (userSnap.hasData && userSnap.data!.exists) {
                            final data = userSnap.data!.data() as Map<String, dynamic>;
                            name = data['name'] ?? 'Volunteer';
                            phone = data['phone_number'] ?? '';
                            location = data['location'] ?? '';
                            skills = List<String>.from(data['skills'] ?? []).join(', ');
                          }

                          return ClayContainer(
                            color: baseColor, borderRadius: 14, depth: 16,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFF8A2387).withValues(alpha: 0.15),
                                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'V',
                                            style: const TextStyle(color: Color(0xFF8A2387), fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            Text('${assignment.role}  •  Match: ${assignment.matchScore}%',
                                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _statusColor(assignment.status).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(assignment.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _statusColor(assignment.status),
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ),
                                    ],
                                  ),
                                  if (location.isNotEmpty || skills.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    if (location.isNotEmpty)
                                      Text('📍 $location', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if (skills.isNotEmpty)
                                      Text('🎯 $skills', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                  if (phone.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _whatsAppNotify(phone, name),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chat, color: Colors.white, size: 14),
                                            SizedBox(width: 6),
                                            Text('WhatsApp Notify',
                                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  ).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return ClayContainer(
      color: baseColor, borderRadius: 14, depth: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
