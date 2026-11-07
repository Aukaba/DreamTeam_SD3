import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/cebu_landmark_service.dart';
import '../services/location_service.dart';
import '../services/saved_location_service.dart';
import 'interactive_location_picker.dart';

/// Selected route endpoint returned by [showRoutePlacePickerSheet].
class SelectedRoutePlace {
  final String label;
  final String subtitle;
  final LatLng location;
  final bool isCurrentLocation;

  const SelectedRoutePlace({
    required this.label,
    required this.subtitle,
    required this.location,
    this.isCurrentLocation = false,
  });
}

/// Opens a modal bottom sheet for choosing a route origin ("From") or destination ("To").
Future<SelectedRoutePlace?> showRoutePlacePickerSheet(
  BuildContext context, {
  required String title,
  required LatLng currentLocation,
  bool allowCurrentLocationOption = true,
  SavedLocationService? savedLocationService,
}) {
  return showModalBottomSheet<SelectedRoutePlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _RoutePlacePickerSheet(
      title: title,
      currentLocation: currentLocation,
      allowCurrentLocationOption: allowCurrentLocationOption,
      savedLocationService: savedLocationService,
    ),
  );
}

class _RoutePlacePickerSheet extends StatefulWidget {
  final String title;
  final LatLng currentLocation;
  final bool allowCurrentLocationOption;
  final SavedLocationService? savedLocationService;

  const _RoutePlacePickerSheet({
    required this.title,
    required this.currentLocation,
    required this.allowCurrentLocationOption,
    this.savedLocationService,
  });

  @override
  State<_RoutePlacePickerSheet> createState() => _RoutePlacePickerSheetState();
}

class _RoutePlacePickerSheetState extends State<_RoutePlacePickerSheet> {
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _lightBlue = Color(0xFFEBF3FE);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<CebuLandmark> _searchResults = <CebuLandmark>[];
  List<SavedLocation> _savedLocations = <SavedLocation>[];
  bool _isSearchingOnline = false;
  bool _isResolvingGps = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLocations();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocations() async {
    try {
      final service = widget.savedLocationService ?? SavedLocationService();
      final items = await service.getSavedLocations();
      if (mounted) {
        setState(() => _savedLocations = items);
      }
    } catch (_) {}
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = <CebuLandmark>[];
        _isSearchingOnline = false;
      });
      return;
    }

    final local = CebuLandmarkService.searchLocal(
      query,
      userLocation: widget.currentLocation,
    );
    setState(() {
      _searchResults = local;
      _isSearchingOnline = query.length >= 3;
    });

    if (query.length < 3) return;

    _debounce = Timer(const Duration(milliseconds: 550), () async {
      final online = await CebuLandmarkService.searchOnline(
        query,
        userLocation: widget.currentLocation,
      );
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _isSearchingOnline = false;
        final merged = List<CebuLandmark>.from(_searchResults);
        for (final item in online) {
          final dup = merged.any(
            (m) =>
                m.id == item.id ||
                (m.name.toLowerCase() == item.name.toLowerCase() &&
                    const Distance().distance(m.location, item.location) < 35),
          );
          if (!dup) merged.add(item);
        }
        _searchResults = merged.take(15).toList();
      });
    });
  }

  Future<void> _selectCurrentGpsLocation() async {
    setState(() => _isResolvingGps = true);
    final gps = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isResolvingGps = false);
    Navigator.pop(
      context,
      SelectedRoutePlace(
        label: 'Your current location',
        subtitle:
            '${gps.latitude.toStringAsFixed(4)}, ${gps.longitude.toStringAsFixed(4)}',
        location: gps,
        isCurrentLocation: true,
      ),
    );
  }

  Future<void> _openPinOnMapPicker() async {
    final picked = await Navigator.push<SelectedRoutePlace>(
      context,
      MaterialPageRoute<SelectedRoutePlace>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _primaryNavy,
            elevation: 0.5,
            title: Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
          ),
          body: InteractiveLocationPicker(
            initialLocation: widget.currentLocation,
            onLocationConfirmed: (loc, address) {
              final shortLabel =
                  InteractiveLocationPicker.formatDisplayName(address).trim();
              Navigator.pop(
                ctx,
                SelectedRoutePlace(
                  label: shortLabel.isNotEmpty ? shortLabel : 'Pinned Location',
                  subtitle: address,
                  location: loc,
                ),
              );
            },
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      Navigator.pop(context, picked);
    }
  }

  String _distanceLabel(LatLng target) {
    final m = const Distance().distance(widget.currentLocation, target);
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000.0).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final popularLandmarks = CebuLandmarkService.landmarks.take(8).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _primaryNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _secondaryGrey),
                    ),
                  ],
                ),
              ),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _primaryNavy,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search street, landmark, school, or mall...',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: _secondaryGrey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _secondaryGrey,
                        size: 20,
                      ),
                      suffixIcon: _isSearchingOnline
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primaryNavy,
                                ),
                              ),
                            )
                          : (hasQuery
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _onQueryChanged('');
                                  },
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: _secondaryGrey,
                                  ),
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Quick Action Row: Current GPS & Pick on Map
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (widget.allowCurrentLocationOption) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _isResolvingGps ? null : _selectCurrentGpsLocation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accentBlue,
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            backgroundColor: _lightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isResolvingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _accentBlue,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text(
                            'Current GPS',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPinOnMapPicker,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryNavy,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text(
                          'Pick on Map',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Results / Saved Places / Popular Landmarks
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  children: [
                    if (hasQuery) ...[
                      if (_searchResults.isEmpty && !_isSearchingOnline)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'No matching places found. Try "Pick on Map".',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: _secondaryGrey,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final lm in _searchResults)
                          _buildPlaceTile(
                            icon: lm.icon,
                            iconColor: lm.color,
                            title: lm.name,
                            subtitle: lm.address,
                            trailing: _distanceLabel(lm.location),
                            onTap: () => Navigator.pop(
                              context,
                              SelectedRoutePlace(
                                label: lm.name,
                                subtitle: lm.address,
                                location: lm.location,
                              ),
                            ),
                          ),
                    ] else ...[
                      if (_savedLocations.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, top: 2),
                          child: Text(
                            'SAVED PLACES',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _secondaryGrey,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        for (final saved in _savedLocations.take(5))
                          _buildPlaceTile(
                            icon: saved.icon,
                            iconColor: saved.color,
                            title: saved.title,
                            subtitle: saved.address,
                            trailing: _distanceLabel(saved.location),
                            onTap: () => Navigator.pop(
                              context,
                              SelectedRoutePlace(
                                label: saved.title,
                                subtitle: saved.address,
                                location: saved.location,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'POPULAR CEBU DESTINATIONS',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _secondaryGrey,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      for (final lm in popularLandmarks)
                        _buildPlaceTile(
                          icon: lm.icon,
                          iconColor: lm.color,
                          title: lm.name,
                          subtitle: lm.address,
                          trailing: _distanceLabel(lm.location),
                          onTap: () => Navigator.pop(
                            context,
                            SelectedRoutePlace(
                              label: lm.name,
                              subtitle: lm.address,
                              location: lm.location,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: _secondaryGrey,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _secondaryGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

