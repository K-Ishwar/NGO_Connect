import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/survey_model.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> with TickerProviderStateMixin {
  List<_SurveyMarker> _markers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  final List<String> _filters = ['All', 'Health', 'Food', 'Shelter', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadAndGeocode();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<LatLng?> _geocodeArea(String area) async {
    try {
      final encoded = Uri.encodeComponent(area);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'NGOConnect/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadAndGeocode() async {
    setState(() => _isLoading = true);
    final snap = await FirebaseFirestore.instance
        .collection('surveys')
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    final surveys = snap.docs.map((d) => SurveyModel.fromMap(d.data(), d.id)).toList();
    final List<_SurveyMarker> markers = [];

    for (final survey in surveys) {
      final coords = await _geocodeArea(survey.area);
      if (coords != null) {
        markers.add(_SurveyMarker(survey: survey, position: coords));
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _isLoading = false;
      });
      if (markers.isNotEmpty) {
        _mapController.move(markers.first.position, 10.0);
      }
    }
  }

  Color _colorForUrgency(String urgency) {
    switch (urgency) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      default: return Colors.green;
    }
  }

  double _radiusForCount(int count) {
    if (count > 500) return 40;
    if (count > 200) return 30;
    if (count > 100) return 22;
    if (count > 50) return 16;
    return 10;
  }

  List<_SurveyMarker> get _filteredMarkers {
    if (_selectedFilter == 'All') return _markers;
    return _markers
        .where((m) => m.survey.problemType.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF8A2387), Color(0xFFE94057)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.map, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Community Needs Heatmap',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Live survey locations', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                  const Spacer(),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadAndGeocode,
                      tooltip: 'Reload',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(20.5937, 78.9629),
              initialZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ngoconnect.app',
              ),
              // Animated pulsing outer halo
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, _) => CircleLayer(
                  circles: _filteredMarkers.map((m) {
                    final base = _radiusForCount(m.survey.peopleCount);
                    final urgFactor = m.survey.urgency == 'High' ? 14.0 : m.survey.urgency == 'Medium' ? 9.0 : 5.0;
                    return CircleMarker(
                      point: m.position,
                      radius: base + (_pulseController.value * urgFactor),
                      color: _colorForUrgency(m.survey.urgency).withValues(alpha: 0.12 + _pulseController.value * 0.22),
                      borderColor: _colorForUrgency(m.survey.urgency).withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    );
                  }).toList(),
                ),
              ),
              // Solid core circle
              CircleLayer(
                circles: _filteredMarkers.map((m) => CircleMarker(
                  point: m.position,
                  radius: _radiusForCount(m.survey.peopleCount),
                  color: _colorForUrgency(m.survey.urgency).withValues(alpha: 0.55),
                  borderColor: _colorForUrgency(m.survey.urgency),
                  borderStrokeWidth: 2.5,
                )).toList(),
              ),
              // Tap-to-open label markers
              MarkerLayer(
                markers: _filteredMarkers.map((m) => Marker(
                  point: m.position,
                  width: 150, height: 42,
                  child: GestureDetector(
                    onTap: () => _showSurveySheet(m.survey),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _colorForUrgency(m.survey.urgency), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _colorForUrgency(m.survey.urgency).withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 13, color: _colorForUrgency(m.survey.urgency)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(m.survey.area,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF8A2387).withValues(alpha: 0.2), blurRadius: 20)],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF8A2387)),
                      SizedBox(height: 16),
                      Text('Geocoding survey locations...', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),

          // Filter chips
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((f) {
                  final selected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedFilter = f),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF8A2387).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF8A2387),
                      elevation: selected ? 4 : 1,
                      labelStyle: TextStyle(
                        color: selected ? const Color(0xFF8A2387) : Colors.black87,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: selected ? const Color(0xFF8A2387) : Colors.black26),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Legend card
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Urgency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 6),
                  _legendRow(Colors.red, 'High  ●●●'),
                  _legendRow(Colors.orange, 'Medium ●●'),
                  _legendRow(Colors.green, 'Low  ●'),
                  const Divider(height: 12),
                  Text('${_filteredMarkers.length} locations',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showSurveySheet(SurveyModel survey) {
    final urgColor = _colorForUrgency(survey.urgency);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [urgColor.withValues(alpha: 0.7), urgColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${survey.problemType} — ${survey.area}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                      child: Text(survey.urgency,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoRow(Icons.people, '${survey.peopleCount} people affected'),
              _infoRow(Icons.calendar_today,
                  'Reported: ${survey.date.day}/${survey.date.month}/${survey.date.year}'),
              if (survey.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(survey.description, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text('View Analytics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A2387),
                    side: const BorderSide(color: Color(0xFF8A2387)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8A2387)),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _SurveyMarker {
  final SurveyModel survey;
  final LatLng position;
  const _SurveyMarker({required this.survey, required this.position});
}
