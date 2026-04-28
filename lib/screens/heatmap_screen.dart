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

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<_SurveyMarker> _markers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final MapController _mapController = MapController();

  final List<String> _filters = ['All', 'Health', 'Food', 'Shelter', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadAndGeocode();
  }

  Future<LatLng?> _geocodeArea(String area) async {
    try {
      final encoded = Uri.encodeComponent(area);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NGOConnect/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
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

    final surveys = snap.docs
        .map((d) => SurveyModel.fromMap(d.data(), d.id))
        .toList();

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

      // Center map on first marker if available
      if (markers.isNotEmpty) {
        _mapController.move(markers.first.position, 10.0);
      }
    }
  }

  Color _colorForUrgency(String urgency) {
    switch (urgency) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
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
        .where((m) =>
            m.survey.problemType.toLowerCase() ==
            _selectedFilter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Community Needs Heatmap'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF8A2387)),
              onPressed: _loadAndGeocode,
              tooltip: 'Reload',
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(20.5937, 78.9629), // India default
              initialZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ngoconnect.app',
              ),
              CircleLayer(
                circles: _filteredMarkers.map((m) {
                  return CircleMarker(
                    point: m.position,
                    radius: _radiusForCount(m.survey.peopleCount),
                    color: _colorForUrgency(m.survey.urgency).withOpacity(0.45),
                    borderColor: _colorForUrgency(m.survey.urgency),
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: _filteredMarkers.map((m) {
                  return Marker(
                    point: m.position,
                    width: 140,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _showSurveySheet(m.survey),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _colorForUrgency(m.survey.urgency)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                size: 12,
                                color: _colorForUrgency(m.survey.urgency)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                m.survey.area,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF8A2387)),
                        SizedBox(height: 12),
                        Text('Geocoding survey locations...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Filter chips
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
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
                      selectedColor: const Color(0xFF8A2387).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF8A2387),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF8A2387)
                            : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF8A2387)
                            : Colors.black26,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Legend
          Positioned(
            top: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Urgency',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 4),
                    _legendRow(Colors.red, 'High'),
                    _legendRow(Colors.orange, 'Medium'),
                    _legendRow(Colors.green, 'Low'),
                    const SizedBox(height: 4),
                    Text('${_filteredMarkers.length} locations',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  ],
                ),
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
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showSurveySheet(SurveyModel survey) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${survey.problemType} in ${survey.area}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.people, '${survey.peopleCount} people affected'),
            _infoRow(Icons.warning_amber,
                'Urgency: ${survey.urgency}'),
            _infoRow(
                Icons.calendar_today,
                'Reported: ${survey.date.toString().split(' ').first}'),
            const SizedBox(height: 8),
            Text(survey.description,
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8A2387)),
          const SizedBox(width: 8),
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
