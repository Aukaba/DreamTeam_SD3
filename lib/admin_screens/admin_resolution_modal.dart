import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_report_detail_modal.dart' show formatRelativeTime;

/// Model representing a user-submitted resolution request from `hazard_resolution_reports`
class AdminResolutionItem {
  final String id;
  final String reportId;
  final String? reportedBy;
  final String hazardCategory;
  final String detectedHazard;
  final String hazardDescription;
  final String severityLevel;
  final String locationAddress;
  final double? latitude;
  final double? longitude;
  final String? originalImageUrl;
  final String resolutionImageUrl;
  final String resolutionNote;
  final String status;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined profile details
  final String reporterName;
  final String? reporterUsername;
  final String? reporterEmail;
  final String? reporterAvatar;
  final String? adminVerifierName;

  const AdminResolutionItem({
    required this.id,
    required this.reportId,
    this.reportedBy,
    required this.hazardCategory,
    required this.detectedHazard,
    required this.hazardDescription,
    required this.severityLevel,
    required this.locationAddress,
    this.latitude,
    this.longitude,
    this.originalImageUrl,
    required this.resolutionImageUrl,
    required this.resolutionNote,
    required this.status,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.reporterName,
    this.reporterUsername,
    this.reporterEmail,
    this.reporterAvatar,
    this.adminVerifierName,
  });

  factory AdminResolutionItem.fromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? reporterProfile,
    Map<String, dynamic>? adminProfile,
  }) {
    final rawCreatedAt = row['created_at']?.toString();
    final DateTime createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawUpdatedAt = row['updated_at']?.toString();
    final DateTime updatedAt = rawUpdatedAt != null
        ? (DateTime.tryParse(rawUpdatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawVerifiedAt = row['verified_at']?.toString();
    final DateTime? verifiedAt = rawVerifiedAt != null
        ? DateTime.tryParse(rawVerifiedAt)?.toLocal()
        : null;

    final double? lat = row['latitude'] != null
        ? double.tryParse(row['latitude'].toString())
        : null;
    final double? lng = row['longitude'] != null
        ? double.tryParse(row['longitude'].toString())
        : null;

    // Reporter profile resolution
    String reporterName = 'Anonymous User';
    String? reporterUsername;
    String? reporterEmail;
    String? reporterAvatar;

    if (reporterProfile != null) {
      final fn = reporterProfile['full_name']?.toString().trim();
      final un = reporterProfile['username']?.toString().trim();
      final em = reporterProfile['email']?.toString().trim();
      reporterAvatar = reporterProfile['avatar_url']?.toString().trim();
      reporterUsername = (un != null && un.isNotEmpty) ? un : null;
      reporterEmail = (em != null && em.isNotEmpty) ? em : null;

      if (fn != null && fn.isNotEmpty) {
        reporterName = fn;
      } else if (un != null && un.isNotEmpty) {
        reporterName = un;
      } else if (em != null && em.isNotEmpty) {
        reporterName = em;
      }
    }

    String? adminVerifierName;
    if (adminProfile != null) {
      final un = adminProfile['username']?.toString().trim();
      final fn = adminProfile['full_name']?.toString().trim();
      adminVerifierName = (un != null && un.isNotEmpty)
          ? un
          : ((fn != null && fn.isNotEmpty) ? fn : 'Admin');
    }

    return AdminResolutionItem(
      id: row['id']?.toString() ?? '',
      reportId: row['report_id']?.toString() ?? '',
      reportedBy: row['reported_by']?.toString(),
      hazardCategory: row['hazard_category']?.toString() ?? 'Hazard',
      detectedHazard: row['detected_hazard']?.toString() ?? 'Hazard Resolution',
      hazardDescription: row['hazard_description']?.toString() ?? '',
      severityLevel: row['severity_level']?.toString() ?? 'Medium',
      locationAddress: row['location_address']?.toString() ?? 'Unknown Location',
      latitude: lat,
      longitude: lng,
      originalImageUrl: row['original_image_url']?.toString(),
      resolutionImageUrl: row['resolution_image_url']?.toString() ?? '',
      resolutionNote: row['resolution_note']?.toString() ?? '',
      status: row['status']?.toString().trim().toLowerCase() ?? 'pending',
      verifiedBy: row['verified_by']?.toString(),
      verifiedAt: verifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      reporterName: reporterName,
      reporterUsername: reporterUsername,
      reporterEmail: reporterEmail,
      reporterAvatar: reporterAvatar,
      adminVerifierName: adminVerifierName,
    );
  }

  AdminResolutionItem copyWith({
    String? status,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? adminVerifierName,
  }) {
    return AdminResolutionItem(
      id: id,
      reportId: reportId,
      reportedBy: reportedBy,
      hazardCategory: hazardCategory,
      detectedHazard: detectedHazard,
      hazardDescription: hazardDescription,
      severityLevel: severityLevel,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      originalImageUrl: originalImageUrl,
      resolutionImageUrl: resolutionImageUrl,
      resolutionNote: resolutionNote,
      status: status ?? this.status,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      reporterName: reporterName,
      reporterUsername: reporterUsername,
      reporterEmail: reporterEmail,
      reporterAvatar: reporterAvatar,
      adminVerifierName: adminVerifierName ?? this.adminVerifierName,
    );
  }
}

/// Helper function to open the Resolution Detail Modal
Future<bool?> showAdminResolutionDetailModal({
  required BuildContext context,
  required AdminResolutionItem resolution,
  VoidCallback? onResolutionUpdated,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _AdminResolutionDetailDialog(
        resolution: resolution,
        onResolutionUpdated: onResolutionUpdated,
      );
    },
  );
}

class _AdminResolutionDetailDialog extends StatefulWidget {
  final AdminResolutionItem resolution;
  final VoidCallback? onResolutionUpdated;

  const _AdminResolutionDetailDialog({
    required this.resolution,
    this.onResolutionUpdated,
  });

  @override
  State<_AdminResolutionDetailDialog> createState() =>
      _AdminResolutionDetailDialogState();
}

class _AdminResolutionDetailDialogState
    extends State<_AdminResolutionDetailDialog> {
  late AdminResolutionItem _item;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _item = widget.resolution;
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      // 1. Fetch admin profile to get admin UUID and admin username
      Map<String, dynamic>? adminProfile;
      try {
        final dynamic adminData = await client
            .from('profiles')
            .select('id, username, full_name, role')
            .eq('role', 'admin')
            .maybeSingle();
        if (adminData is Map<String, dynamic>) {
          adminProfile = adminData;
        }
      } catch (e) {
        debugPrint('Could not fetch admin profile: $e');
      }

      final adminId = currentUserId ??
          adminProfile?['id']?.toString() ??
          'c2bd826e-5a16-4c61-9f8b-bb31552a7c8f';
      final adminUsername = adminProfile?['username']?.toString() ??
          adminProfile?['full_name']?.toString() ??
          'admin';

      final nowIso = DateTime.now().toUtc().toIso8601String();

      // 2. Update hazard_resolution_reports
      final Map<String, dynamic> resolutionUpdate = {
        'status': newStatus, // 'resolved' or 'rejected'
        'verified_by': adminId,
        'verified_at': nowIso,
        'updated_at': nowIso,
      };

      await client
          .from('hazard_resolution_reports')
          .update(resolutionUpdate)
          .eq('id', _item.id);

      // 3. Update parent ReportTable status
      if (newStatus == 'resolved') {
        try {
          await client.from('ReportTable').update({
            'status': 'resolved',
            'resolution_status': 'approved',
            'resolved_at': nowIso,
          }).eq('reportID', _item.reportId);
        } catch (repErr) {
          debugPrint('ReportTable sync error: $repErr');
        }
      } else if (newStatus == 'rejected') {
        try {
          await client.from('ReportTable').update({
            'resolution_status': 'rejected',
          }).eq('reportID', _item.reportId);
        } catch (repErr) {
          debugPrint('ReportTable sync error: $repErr');
        }
      }

      if (!mounted) return;
      setState(() {
        _item = _item.copyWith(
          status: newStatus,
          verifiedBy: adminId,
          verifiedAt: DateTime.now(),
          adminVerifierName: adminUsername,
        );
        _isSubmitting = false;
      });

      widget.onResolutionUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'resolved'
                ? 'Resolution accepted! Hazard marked as resolved by @$adminUsername.'
                : 'Resolution request rejected.',
          ),
          backgroundColor: newStatus == 'resolved'
              ? const Color(0xFF1A7A45)
              : const Color(0xFFE53935),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Error updating resolution status: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update resolution: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isSmallScreen = screenWidth < 380;
    final isTablet = screenWidth >= 600;

    final dialogMaxWidth = isTablet ? 600.0 : 540.0;

    final isPending = _item.status.toLowerCase() == 'pending';
    final isResolved = _item.status.toLowerCase() == 'resolved' ||
        _item.status.toLowerCase() == 'approved';

    Color statusBg;
    Color statusText;
    if (isResolved) {
      statusBg = const Color(0xFFE8F7F0);
      statusText = const Color(0xFF1A7A45);
    } else if (isPending) {
      statusBg = const Color(0xFFFFF4E5);
      statusText = const Color(0xFFD97706);
    } else {
      statusBg = const Color(0xFFFFEBEE);
      statusText = const Color(0xFFE53935);
    }

    final contentPadding = isSmallScreen ? 14.0 : (isTablet ? 22.0 : 18.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12.0 : 20.0,
        vertical: 20.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth,
          maxHeight: screenHeight * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Responsive Modal Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: isSmallScreen ? 12 : 15,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE8EEF2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.task_alt,
                      color: Color(0xFF1976D2),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Resolution Review',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1A2B4A),
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isSmallScreen) ...[
                          const SizedBox(height: 1),
                          Text(
                            'Review user proof to mark hazard resolved',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7B9BAD),
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _item.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: statusText,
                        fontSize: isSmallScreen ? 9.5 : 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE8EEF2),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Color(0xFF5B6B7A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Before & After Images
                    _buildImageComparison(isSmallScreen, isTablet),

                    SizedBox(height: isSmallScreen ? 14 : 18),

                    // Hazard and location
                    Text(
                      _item.detectedHazard,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1A2B4A),
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on_outlined,
                              size: 14, color: Color(0xFF7B9BAD)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _item.locationAddress,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7B9BAD),
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),
                    const Divider(color: Color(0xFFF0F4F7), height: 1),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // User Resolution Note
                    Text(
                      'User Resolution Note',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5B6B7A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 11 : 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EEF2)),
                      ),
                      child: Text(
                        _item.resolutionNote.isNotEmpty
                            ? _item.resolutionNote
                            : 'No resolution note provided by user.',
                        style: GoogleFonts.inter(
                          color: _item.resolutionNote.isNotEmpty
                              ? const Color(0xFF1A2B4A)
                              : const Color(0xFFA8BFCA),
                          fontSize: isSmallScreen ? 12 : 13,
                          height: 1.4,
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Reporter details
                    _buildReporterSection(isSmallScreen),

                    if (_item.adminVerifierName != null || _item.verifiedAt != null) ...[
                      SizedBox(height: isSmallScreen ? 10 : 14),
                      _buildVerificationSection(isSmallScreen),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer / Actions (Responsive)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: isSmallScreen ? 12 : 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBFC),
                border: Border(top: BorderSide(color: Color(0xFFE8EEF2))),
              ),
              child: isPending
                  ? _buildPendingActionButtons(isSmallScreen)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActionButtons(bool isSmallScreen) {
    if (isSmallScreen) {
      // Stack buttons vertically on small screens to prevent text overflow
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _updateStatus('resolved'),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                _isSubmitting ? 'Saving...' : 'Accept & Mark Resolved',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7A45),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => _updateStatus('rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Reject Proof',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => _updateStatus('rejected'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
              side: const BorderSide(color: Color(0xFFFFCDD2)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Reject Proof',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _updateStatus('resolved'),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              _isSubmitting ? 'Saving...' : 'Accept & Mark Resolved',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A7A45),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageComparison(bool isSmallScreen, bool isTablet) {
    final imageHeight = isSmallScreen ? 125.0 : (isTablet ? 175.0 : 145.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Hazard Photo',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B6B7A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _buildImageBox(
                    url: _item.originalImageUrl,
                    fallbackIcon: Icons.warning_amber_rounded,
                    height: imageHeight,
                    label: 'Original',
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Resolution Proof',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A7A45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle,
                          size: 11, color: Color(0xFF1A7A45)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildImageBox(
                    url: _item.resolutionImageUrl,
                    fallbackIcon: Icons.camera_alt_outlined,
                    height: imageHeight,
                    label: 'Proof',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageBox({
    required String? url,
    required IconData fallbackIcon,
    required double height,
    required String label,
  }) {
    if (url != null && url.isNotEmpty) {
      return InkWell(
        onTap: () => _showFullImagePreview(url, label),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEF2)),
            color: const Color(0xFFF4F7F9),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(fallbackIcon, height),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xA6000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in, color: Colors.white, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        'ZOOM',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildPlaceholder(fallbackIcon, height);
  }

  Widget _buildPlaceholder(IconData icon, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Center(
        child: Icon(icon, size: 36, color: const Color(0xFFA8BFCA)),
      ),
    );
  }

  void _showFullImagePreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                clipBehavior: Clip.none,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: const Text('Unable to load full-size image'),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: () => Navigator.of(dialogCtx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xB3000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReporterSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isSmallScreen ? 16 : 18,
            backgroundColor: const Color(0xFFE8F4FB),
            backgroundImage: (_item.reporterAvatar != null &&
                    _item.reporterAvatar!.isNotEmpty)
                ? NetworkImage(_item.reporterAvatar!)
                : null,
            child: (_item.reporterAvatar == null || _item.reporterAvatar!.isEmpty)
                ? Text(
                    _item.reporterName.isNotEmpty
                        ? _item.reporterName[0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1976D2),
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Resolved by: ${_item.reporterName}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A2B4A),
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Submitted ${formatRelativeTime(_item.createdAt)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7B9BAD),
                    fontSize: isSmallScreen ? 10.5 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7E4CD)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified,
              color: const Color(0xFF1A7A45), size: isSmallScreen ? 18 : 20),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verified by: ${_item.adminVerifierName ?? "Admin"}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A7A45),
                    fontSize: isSmallScreen ? 11.5 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_item.verifiedAt != null)
                  Text(
                    formatRelativeTime(_item.verifiedAt!),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2E7D32),
                      fontSize: isSmallScreen ? 10 : 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
