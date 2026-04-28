import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/survey_model.dart';
import 'survey_analytics_screen.dart';
import 'heatmap_screen.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  final Color baseColor = const Color(0xFFF2F2F2);
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _filterUrgency = 'All';
  String _filterProblem = 'All';
  String _searchText = '';
  bool _isMapView = false;

  final _urgencies = ['All', 'High', 'Medium', 'Low'];
  final _problems = [
    'All',
    'Health',
    'Food',
    'Water & Sanitation',
    'Education',
    'Shelter',
    'Employment',
    'Disaster Relief',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pledge(String surveyId) async {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('surveys')
          .doc(surveyId)
          .update({
            'pledges': FieldValue.arrayUnion([myId]),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                Icon(Icons.handshake, color: Colors.white),
                SizedBox(width: 8),
                Text('Support pledged! The NGO will be notified.'),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _removePledge(String surveyId) async {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('surveys')
          .doc(surveyId)
          .update({
            'pledges': FieldValue.arrayRemove([myId]),
          });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: baseColor,
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF8A2387).withValues(alpha: 0.1),
                child: const Text(
                  'Advanced Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8A2387),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Urgency
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Urgency Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._urgencies.map(
                (u) => RadioListTile(
                  title: Text(u),
                  value: u,
                  groupValue: _filterUrgency,
                  activeColor: const Color(0xFF8A2387),
                  onChanged: (v) {
                    setState(() => _filterUrgency = v!);
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(),
              // Problem Type
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Problem Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: _problems
                      .map(
                        (p) => RadioListTile(
                          title: Text(p),
                          value: p,
                          groupValue: _filterProblem,
                          activeColor: const Color(0xFF8A2387),
                          onChanged: (v) {
                            setState(() => _filterProblem = v!);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2387),
                  ),
                  icon: const Icon(Icons.clear_all, color: Colors.white),
                  label: const Text(
                    'Reset Filters',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterUrgency = 'All';
                      _filterProblem = 'All';
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF8A2387)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.public,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Community Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'All NGO surveys — Open data sharing',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2F2F2),
              const Color(0xFFE6E6FA).withValues(alpha: 0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('surveys').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Parse all surveys
            final allSurveys = snap.data!.docs.map((d) {
              return SurveyModel.fromMap(
                d.data() as Map<String, dynamic>,
                d.id,
              );
            }).toList();

            // Apply filters
            var filtered = allSurveys.where((s) {
              final matchUrgency =
                  _filterUrgency == 'All' || s.urgency == _filterUrgency;
              final matchProblem =
                  _filterProblem == 'All' || s.problemType == _filterProblem;
              final matchSearch =
                  _searchText.isEmpty ||
                  s.area.toLowerCase().contains(_searchText.toLowerCase()) ||
                  s.description.toLowerCase().contains(
                    _searchText.toLowerCase(),
                  );
              return matchUrgency && matchProblem && matchSearch;
            }).toList();

            // Sort: High urgency first, then by date
            filtered.sort((a, b) {
              const order = {'High': 0, 'Medium': 1, 'Low': 2};
              final urgCompare = (order[a.urgency] ?? 1).compareTo(
                order[b.urgency] ?? 1,
              );
              if (urgCompare != 0) return urgCompare;
              return b.date.compareTo(a.date);
            });

            // Aggregate stats
            final totalPeople = allSurveys.fold<int>(
              0,
              (sum, s) => sum + s.peopleCount,
            );
            final highCount = allSurveys
                .where((s) => s.urgency == 'High')
                .length;

            return Column(
              children: [
                // ── Top Stats ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFF8A2387)],
                    ),
                  ),
                  child: Row(
                    children: [
                      _statPill(
                        'Total Surveys',
                        allSurveys.length.toString(),
                        Icons.assignment,
                        Colors.white,
                      ),
                      _statDivider(),
                      _statPill(
                        'People Affected',
                        _formatNum(totalPeople),
                        Icons.people,
                        Colors.white,
                      ),
                      _statDivider(),
                      _statPill(
                        'High Urgency',
                        highCount.toString(),
                        Icons.warning_amber,
                        Colors.redAccent.shade100,
                      ),
                      _statDivider(),
                      _statPill(
                        'NGOs Active',
                        _countNgos(allSurveys).toString(),
                        Icons.business,
                        Colors.lightBlueAccent.shade100,
                      ),
                    ],
                  ),
                ),

                // ── Search & Filters ───────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: -15,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchText = v),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search by area or description...',
                          icon: const Icon(
                            Icons.search,
                            color: Color(0xFF8A2387),
                          ),
                          suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchText = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Map/List Toggle ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.list, size: 18),
                          label: const Text('List View'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isMapView ? const Color(0xFF8A2387) : Colors.grey.shade300,
                            foregroundColor: !_isMapView ? Colors.white : Colors.black54,
                            elevation: !_isMapView ? 2 : 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                            ),
                          ),
                          onPressed: () => setState(() => _isMapView = false),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Map View'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMapView ? const Color(0xFF8A2387) : Colors.grey.shade300,
                            foregroundColor: _isMapView ? Colors.white : Colors.black54,
                            elevation: _isMapView ? 2 : 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Survey List ────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _SurveyHubCard(
                            survey: filtered[i],
                            onPledge: _pledge,
                            onRemovePledge: _removePledge,
                            onViewAnalytics: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SurveyAnalyticsScreen(survey: filtered[i]),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2));

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'No surveys match your filters.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatNum(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toString();

  int _countNgos(List<SurveyModel> surveys) =>
      surveys.map((s) => s.ngoId).toSet().length;
}

// ── Individual Survey Card ─────────────────────────────────────────────────────
class _SurveyHubCard extends StatelessWidget {
  final SurveyModel survey;
  final Future<void> Function(String) onPledge;
  final Future<void> Function(String) onRemovePledge;
  final VoidCallback onViewAnalytics;

  const _SurveyHubCard({
    required this.survey,
    required this.onPledge,
    required this.onRemovePledge,
    required this.onViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final baseColor = const Color(0xFFF2F2F2);
    Color urgColor;
    switch (survey.urgency) {
      case 'High': urgColor = Colors.red; break;
      case 'Medium': urgColor = Colors.orange; break;
      default: urgColor = Colors.green;
    }
    final dateStr =
        '${survey.date.day}/${survey.date.month}/${survey.date.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 16,
        depth: 20,
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Urgency bar top
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: urgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Problem + Urgency badge + NGO badge
                    Row(
                      children: [
                        Text(
                          survey.problemType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: urgColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: urgColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: urgColor,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                survey.urgency,
                                style: TextStyle(
                                  color: urgColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Area
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF8A2387),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          survey.area,
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (survey.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        survey.description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Stats row
                    Row(
                      children: [
                        _infoPill(
                          Icons.people,
                          '${survey.peopleCount} affected',
                          Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        // Response count from Firestore
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('survey_responses')
                              .where('survey_id', isEqualTo: survey.id)
                              .get(),
                          builder: (ctx, snap) {
                            final count = snap.data?.docs.length ?? 0;
                            return _infoPill(
                              Icons.assignment_turned_in,
                              '$count responses',
                              Colors.green,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // NGO name + Pledge/Analytics buttons
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('surveys')
                          .doc(survey.id)
                          .snapshots(),
                      builder: (ctx, surveySnap) {
                        final pledges =
                            surveySnap.hasData && surveySnap.data!.exists
                            ? List<String>.from(
                                (surveySnap.data!.data() as Map)['pledges'] ??
                                    [],
                              )
                            : <String>[];
                        final myPledged = pledges.contains(myId);
                        final isMyOwnSurvey = survey.ngoId == myId;
                        final ngoName = survey.ngoName.isNotEmpty
                            ? survey.ngoName
                            : 'NGO';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // NGO name badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.business,
                                        size: 11,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ngoName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (pledges.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.handshake,
                                              size: 11,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${pledges.length} NGOs Pledged Support',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: (pledges.length / 5).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          backgroundColor:
                                              Colors.green.shade100,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Colors.green),
                                          minHeight: 4,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Action buttons
                            Row(
                              children: [
                                // View Analytics
                                Expanded(
                                  child: GestureDetector(
                                    onTap: onViewAnalytics,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF8A2387,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF8A2387,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.bar_chart,
                                            color: Color(0xFF8A2387),
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'View Data',
                                            style: TextStyle(
                                              color: Color(0xFF8A2387),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Pledge Support (only for other NGOs' surveys)
                                if (!isMyOwnSurvey)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => myPledged
                                          ? onRemovePledge(survey.id!)
                                          : onPledge(survey.id!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: myPledged
                                              ? null
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFF8A2387),
                                                    Color(0xFFE94057),
                                                  ],
                                                ),
                                          color: myPledged
                                              ? Colors.green.shade50
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: myPledged
                                              ? Border.all(
                                                  color: Colors.green.shade300,
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              myPledged
                                                  ? Icons.check_circle
                                                  : Icons.handshake,
                                              color: myPledged
                                                  ? Colors.green
                                                  : Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              myPledged
                                                  ? 'Pledged ✓'
                                                  : 'Pledge Support',
                                              style: TextStyle(
                                                color: myPledged
                                                    ? Colors.green
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: Colors.blue,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Your Survey',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
