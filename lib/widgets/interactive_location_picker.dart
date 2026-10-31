import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Interactive Location Picker & Reverse Geocoding Widget.
///
/// Implements:
/// - OpenStreetMap Nominatim forward search with 600ms debounce
/// - Interactive map with single pin selection
/// - 800ms debounced reverse-geocoding on drag / pan gestures
/// - Optional current GPS location detection via Geolocator
class InteractiveLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final ValueChanged<LatLng>? onLocationChanged;
  final void Function(LatLng location, String address)? onLocationConfirmed;

  const InteractiveLocationPicker({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.onLocationChanged,
    this.onLocationConfirmed,
  });

  @override
  State<InteractiveLocationPicker> createState() =>
      _InteractiveLocationPickerState();
}

class _InteractiveLocationPickerState extends State<InteractiveLocationPicker> {
  // Map and location state
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Debouncing & async state
  Timer? _searchDebounce;
  Timer? _reverseGeocodeDebounce;
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _isReverseGeocoding = false;

  // Defaults
  static const LatLng _defaultLocation = LatLng(10.3157, 123.8854); // Cebu City
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _secondaryGrey = Color(0xFF8A94A6);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchController.text = widget.initialAddress!;
    } else {
      _reverseGeocode(_selectedLocation);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // A. FORWARD SEARCH & AUTOCOMPLETE (OpenStreetMap Nominatim)
  // ---------------------------------------------------------------------------
  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    final clean = query.trim();
    if (clean.length < 3) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
      });
      return;
    }

    // Debounce search keystrokes by 600ms to avoid spamming the Nominatim API
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isSearchingLocation = true;
      });

      // Region scoping: automatically append region if not present
      final searchQuery =
          clean.toLowerCase().contains('cebu') ? clean : '$clean, Cebu';

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&addressdetails=1&countrycodes=ph&limit=5',
        );

        // Note on Flutter Web: Avoid custom User-Agent headers that trigger CORS preflight failures
        final response =
            await http.get(url).timeout(const Duration(seconds: 4));

        List data = [];
        if (response.statusCode == 200) {
          data = json.decode(response.body);
        }

        // Fallback to raw query if scoped query returned no items
        if (data.isEmpty && searchQuery != clean) {
          final fallbackUrl = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&addressdetails=1&countrycodes=ph&limit=5',
          );
          final fallbackResp =
              await http.get(fallbackUrl).timeout(const Duration(seconds: 4));
          if (fallbackResp.statusCode == 200) {
            data = json.decode(fallbackResp.body);
          }
        }

        if (mounted) {
          setState(() {
            _locationSuggestions = data.cast<Map<String, dynamic>>();
          });
        }
      } catch (e) {
        debugPrint('Forward location search error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSearchingLocation = false;
          });
        }
      }
    });
  }

  void _onSuggestionTapped(Map<String, dynamic> option) {
    final lat = double.tryParse(option['lat']?.toString() ?? '');
    final lon = double.tryParse(option['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;

    final name = option['name']?.toString() ?? '';
    final displayNameRaw = option['display_name']?.toString() ?? '';
    final parts = displayNameRaw.split(',');

    final title = name.isNotEmpty ? name.trim() : parts.first.trim();

    setState(() {
      _selectedLocation = LatLng(lat, lon);
      _locationSuggestions = [];
      _searchController.text = title;
    });

    _mapController.move(_selectedLocation, 15.0);
    FocusScope.of(context).unfocus();

    widget.onLocationChanged?.call(_selectedLocation);
  }

  // ---------------------------------------------------------------------------
  // B. REVERSE GEOCODING (Debounced on Map Drag)
  // ---------------------------------------------------------------------------
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _selectedLocation = camera.center;
      });

      widget.onLocationChanged?.call(_selectedLocation);

      // Debounce reverse geocoding requests by 800ms
      _reverseGeocodeDebounce?.cancel();
      _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 800), () {
        _reverseGeocode(camera.center);
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          final raw = data['display_name'].toString();
          // Extract display_name and take the top 2 comma-separated segments
          final formatted = raw.split(',').take(2).join(', ').trim();
          if (mounted) {
            setState(() {
              _searchController.text = formatted;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // C. GPS CURRENT LOCATION DETECTION
  // ---------------------------------------------------------------------------
  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final current = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _selectedLocation = current;
      });

      _mapController.move(current, 15.0);
      await _reverseGeocode(current);
      widget.onLocationChanged?.call(current);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ---------------------------------------------------------------------
        // 1. FLUTTER MAP (Background)
        // ---------------------------------------------------------------------
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedLocation,
            initialZoom: 15.0,
            onPositionChanged: _onMapPositionChanged,
            onTap: (_, __) {
              _searchFocusNode.unfocus();
              if (_locationSuggestions.isNotEmpty) {
                setState(() => _locationSuggestions = []);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.dreamteam.sd3',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLocation,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 42,
                    color: Color(0xFFE53E3E), // Pin Red
                  ),
                ),
              ],
            ),
          ],
        ),

        // ---------------------------------------------------------------------
        // 2. FLOATING TOP SEARCH BAR & AUTOCOMPLETE CARD
        // ---------------------------------------------------------------------
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _primaryNavy,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search location or street',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: _secondaryGrey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _secondaryGrey,
                        size: 22,
                      ),
                      suffixIcon: _isSearchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primaryNavy,
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: _secondaryGrey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _locationSuggestions = [];
                                    });
                                  },
                                )
                              : const Icon(
                                  Icons.location_on_outlined,
                                  color: _secondaryGrey,
                                ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Suggestions Dropdown Card
                if (_locationSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _locationSuggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final option = _locationSuggestions[index];
                          final name = option['name']?.toString() ?? '';
                          final displayNameRaw =
                              option['display_name']?.toString() ?? '';
                          final parts = displayNameRaw.split(',');

                          final title =
                              name.isNotEmpty ? name.trim() : parts.first.trim();
                          final subtitle = parts.length > 1
                              ? parts
                                  .skip(name.isNotEmpty ? 0 : 1)
                                  .take(2)
                                  .join(', ')
                                  .trim()
                              : displayNameRaw;

                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Color(0xFF19456B),
                              size: 22,
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              subtitle,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _secondaryGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _onSuggestionTapped(option),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // 3. REVERSE GEOCODING STATUS BADGE & GPS BUTTON
        // ---------------------------------------------------------------------
        Positioned(
          right: 16,
          bottom: widget.onLocationConfirmed != null ? 80 : 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isReverseGeocoding)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryNavy,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Locating...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),

              // GPS My Location Floating Button
              FloatingActionButton.small(
                heroTag: 'interactive_picker_gps',
                backgroundColor: Colors.white,
                foregroundColor: _primaryNavy,
                elevation: 4,
                onPressed: _fetchCurrentLocation,
                child: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
        ),

        // ---------------------------------------------------------------------
        // 4. CONFIRM LOCATION BUTTON (If callback provided)
        // ---------------------------------------------------------------------
        if (widget.onLocationConfirmed != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onLocationConfirmed!(
                    _selectedLocation,
                    _searchController.text,
                  );
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  'Confirm Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

