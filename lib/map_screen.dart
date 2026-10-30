import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'models/place_recommendation.dart';
import 'services/gemini_map_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final GeminiMapService _geminiService = GeminiMapService();

  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  bool _isSearching = false;

  List<PlaceRecommendation> _recommendations = [];
  PlaceRecommendation? _selectedPlace;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable GPS.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = userLatLng;
        });
        _mapController.move(userLatLng, 15.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _performGeminiSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (!_geminiService.isConfigured) {
      _showApiKeyDialog(onConfigured: () => _performGeminiSearch());
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedPlace = null;
    });

    try {
      final refLat = _currentLocation?.latitude ?? _mapController.camera.center.latitude;
      final refLng = _currentLocation?.longitude ?? _mapController.camera.center.longitude;

      final results = await _geminiService.searchPlaces(
        query: query,
        referenceLat: refLat,
        referenceLng: refLng,
      );

      if (!mounted) return;

      setState(() {
        _recommendations = results;
        if (results.isNotEmpty) {
          _selectedPlace = results.first;
        }
      });

      if (results.isNotEmpty) {
        _mapController.move(
          LatLng(results.first.latitude, results.first.longitude),
          14.0,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemini found no matching places. Try another prompt!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showApiKeyDialog({VoidCallback? onConfigured}) {
    final keyController = TextEditingController(text: _geminiService.currentApiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Gemini API Key Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API key to enable Natural Language Map Search. You can get one for free at Google AI Studio.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newKey = keyController.text.trim();
              if (newKey.isNotEmpty) {
                _geminiService.setCustomApiKey(newKey);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gemini API Key saved!')),
                );
                onConfigured?.call();
              }
            },
            child: const Text('Save & Search'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'cafe':
        return Colors.orange.shade700;
      case 'park':
      case 'nature':
        return Colors.green.shade700;
      case 'restaurant':
        return Colors.red.shade600;
      case 'landmark':
      case 'culture':
        return Colors.deepPurple;
      case 'shopping':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cafe':
        return Icons.local_cafe;
      case 'park':
      case 'nature':
        return Icons.park;
      case 'restaurant':
        return Icons.restaurant;
      case 'landmark':
      case 'culture':
        return Icons.account_balance;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI Map Search'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: _geminiService.isConfigured ? Colors.green : Colors.orange,
            ),
            tooltip: 'Gemini API Key',
            onPressed: () => _showApiKeyDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(51.509364, -0.128928),
              initialZoom: 9.2,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, __) {
                if (_selectedPlace != null) {
                  setState(() => _selectedPlace = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dreamteam_sd3',
              ),
              // Current User GPS Marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              // Gemini Place Recommendations Markers
              if (_recommendations.isNotEmpty)
                MarkerLayer(
                  markers: _recommendations.map((place) {
                    final isSelected = _selectedPlace == place;
                    final markerColor = _getCategoryColor(place.category);

                    return Marker(
                      point: LatLng(place.latitude, place.longitude),
                      width: isSelected ? 52 : 42,
                      height: isSelected ? 52 : 42,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPlace = place);
                          _mapController.move(
                            LatLng(place.latitude, place.longitude),
                            _mapController.camera.zoom,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.amberAccent : Colors.white,
                              width: isSelected ? 3.5 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.4),
                                blurRadius: isSelected ? 12 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCategoryIcon(place.category),
                            color: Colors.white,
                            size: isSelected ? 26 : 20,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Floating Natural Language Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _performGeminiSearch(),
                        decoration: const InputDecoration(
                          hintText: "Ask Gemini: 'quiet coffee shops', 'parks nearby'...",
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else ...[
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _recommendations.clear();
                              _selectedPlace = null;
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.deepPurple),
                        onPressed: _performGeminiSearch,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Selected Place Recommendation Card (Bottom Sheet style)
          if (_selectedPlace != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 80, // leaves room for the FAB
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(_selectedPlace!.category).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(_selectedPlace!.category),
                                  size: 14,
                                  color: _getCategoryColor(_selectedPlace!.category),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedPlace!.category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getCategoryColor(_selectedPlace!.category),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => setState(() => _selectedPlace = null),
                            child: const Icon(Icons.close, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedPlace!.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedPlace!.description,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          const Text(
                            'Recommended by Gemini',
                            style: TextStyle(fontSize: 11, color: Colors.deepPurple, fontStyle: FontStyle.italic),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            icon: const Icon(Icons.center_focus_strong, size: 16),
                            label: const Text('Focus', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _mapController.move(
                                LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude),
                                16.0,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoadingLocation ? null : _fetchCurrentLocation,
        tooltip: 'My Location',
        child: _isLoadingLocation
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}
