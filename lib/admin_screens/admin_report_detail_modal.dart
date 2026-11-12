import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportItem {
  final String reportId;
  final String? userId;
  final String hazardCategory;
  final String detectedHazard;
  final String severityLevel;
  final int confidence;
  final String locationAddress;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime createdAt;
  final String description;
  final String status;
  final int pointsAwarded;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? resolvedAt;
  final String? resolutionStatus;
  final String? resolutionImageUrl;
  final String? resolutionReportedBy;
  final DateTime? resolutionReportedAt;
  final int resolutionCount;
  final String reporterName;
  final String? reporterUsername;
  final String? reporterEmail;
  final String? reporterAvatarUrl;

  const AdminReportItem({
    required this.reportId,
    this.userId,
    required this.hazardCategory,
    required this.detectedHazard,
    required this.severityLevel,
    required this.confidence,
    required this.locationAddress,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.createdAt,
    required this.description,
    required this.status,
    this.pointsAwarded = 0,
    this.verifiedBy,
    this.verifiedAt,
    this.resolvedAt,
    this.resolutionStatus,
    this.resolutionImageUrl,
    this.resolutionReportedBy,
    this.resolutionReportedAt,
    this.resolutionCount = 0,
    required this.reporterName,
    this.reporterUsername,
    this.reporterEmail,
    this.reporterAvatarUrl,
  });

  factory AdminReportItem.fromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? profile,
  }) {
    final rawCategory = row['hazard_category']?.toString().trim();
    final category = (rawCategory != null && rawCategory.isNotEmpty)
        ? rawCategory
        : 'General Hazard';

    final rawDetected = row['detected_hazard']?.toString().trim();
    final detected = (rawDetected != null && rawDetected.isNotEmpty)
        ? rawDetected
        : category;

    final rawAddress = row['location_address']?.toString().trim();
    final lat = double.tryParse(row['latitude']?.toString() ?? '');
    final lng = double.tryParse(row['longitude']?.toString() ?? '');
    String address = 'Location not specified';
    if (rawAddress != null && rawAddress.isNotEmpty) {
      address = rawAddress;
    } else if (lat != null && lng != null) {
      address = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }

    final rawConfidence = row['confidence'];
    final int confidence = rawConfidence is num
        ? rawConfidence.round().clamp(1, 100)
        : (int.tryParse(rawConfidence?.toString() ?? '')?.clamp(1, 100) ?? 95);

    final rawCreatedAt = row['created_at']?.toString();
    final DateTime createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawVerifiedAt = row['verified_at']?.toString();
    final DateTime? verifiedAt = rawVerifiedAt != null
        ? DateTime.tryParse(rawVerifiedAt)?.toLocal()
        : null;

    final rawResolvedAt = row['resolved_at']?.toString();
    final DateTime? resolvedAt = rawResolvedAt != null
        ? DateTime.tryParse(rawResolvedAt)?.toLocal()
        : null;

    final rawResolutionReportedAt = row['resolution_reported_at']?.toString();
    final DateTime? resolutionReportedAt = rawResolutionReportedAt != null
        ? DateTime.tryParse(rawResolutionReportedAt)?.toLocal()
        : null;

    String reporterName = 'Community Member';
    String? reporterUsername;
    String? reporterEmail;
    String? reporterAvatarUrl;

    if (profile != null) {
      final fn = profile['full_name']?.toString().trim();
      final un = profile['username']?.toString().trim();
      final em = profile['email']?.toString().trim();
      final av = profile['avatar_url']?.toString().trim();

      if (fn != null && fn.isNotEmpty) {
        reporterName = fn;
      } else if (un != null && un.isNotEmpty) {
        reporterName = un;
      } else if (em != null && em.isNotEmpty) {
        reporterName = em.split('@').first;
      }

      reporterUsername = un;
      reporterEmail = em;
      reporterAvatarUrl = av;
    } else if (row['user_id'] != null &&
        row['user_id'].toString().trim().isNotEmpty) {
      final uid = row['user_id'].toString().trim();
      reporterName = 'User ${uid.length >= 6 ? uid.substring(0, 6) : uid}';
    }

    final rawPoints = row['points_awarded'];
    final pointsAwarded =
        rawPoints is num ? rawPoints.round() : int.tryParse(rawPoints?.toString() ?? '') ?? 0;

    final rawResCount = row['resolution_count'];
    final resolutionCount =
        rawResCount is num ? rawResCount.round() : int.tryParse(rawResCount?.toString() ?? '') ?? 0;

    return AdminReportItem(
      reportId: row['reportID']?.toString() ?? row['report_id']?.toString() ?? '',
      userId: row['user_id']?.toString(),
      hazardCategory: category,
      detectedHazard: detected,
      severityLevel: row['severity_level']?.toString() ?? 'Medium',
      confidence: confidence,
      locationAddress: address,
      latitude: lat,
      longitude: lng,
      imageUrl: row['image_url']?.toString(),
      createdAt: createdAt,
      description: row['description']?.toString() ?? '',
      status: row['status']?.toString().trim().toLowerCase() ?? 'pending',
      pointsAwarded: pointsAwarded,
      verifiedBy: row['verified_by']?.toString(),
      verifiedAt: verifiedAt,
      resolvedAt: resolvedAt,
      resolutionStatus: row['resolution_status']?.toString(),
      resolutionImageUrl: row['resolution_image_url']?.toString(),
      resolutionReportedBy: row['resolution_reported_by']?.toString(),
      resolutionReportedAt: resolutionReportedAt,
      resolutionCount: resolutionCount,
      reporterName: reporterName,
      reporterUsername: reporterUsername,
      reporterEmail: reporterEmail,
      reporterAvatarUrl: reporterAvatarUrl,
    );
  }

  AdminReportItem copyWith({
    String? status,
    String? verifiedBy,
    DateTime? verifiedAt,
  }) {
    return AdminReportItem(
      reportId: reportId,
      userId: userId,
      hazardCategory: hazardCategory,
      detectedHazard: detectedHazard,
      severityLevel: severityLevel,
      confidence: confidence,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      createdAt: createdAt,
      description: description,
      status: status ?? this.status,
      pointsAwarded: pointsAwarded,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      resolvedAt: resolvedAt,
      resolutionStatus: resolutionStatus,
      resolutionImageUrl: resolutionImageUrl,
      resolutionReportedBy: resolutionReportedBy,
      resolutionReportedAt: resolutionReportedAt,
      resolutionCount: resolutionCount,
      reporterName: reporterName,
      reporterUsername: reporterUsername,
      reporterEmail: reporterEmail,
      reporterAvatarUrl: reporterAvatarUrl,
    );
  }
}

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.isNegative || difference.inSeconds < 45) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    return '$mins min${mins == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    final hrs = difference.inHours;
    return '$hrs hr${hrs == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  } else {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}

Future<bool?> showAdminReportDetailModal({
  required BuildContext context,
  required AdminReportItem report,
  VoidCallback? onReportUpdated,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _AdminReportDetailDialog(
        initialReport: report,
        onReportUpdated: onReportUpdated,
      );
    },
  );
}

class _AdminReportDetailDialog extends StatefulWidget {
  final AdminReportItem initialReport;
  final VoidCallback? onReportUpdated;

  const _AdminReportDetailDialog({
    required this.initialReport,
    this.onReportUpdated,
  });

  @override
  State<_AdminReportDetailDialog> createState() => _AdminReportDetailDialogState();
}

class _AdminReportDetailDialogState extends State<_AdminReportDetailDialog> {
  late AdminReportItem _report;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      final Map<String, dynamic> updatePayload = {
        'status': newStatus,
      };

      if (newStatus == 'active') {
        updatePayload['verified_by'] = currentUserId;
        updatePayload['verified_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await client
          .from('ReportTable')
          .update(updatePayload)
          .eq('reportID', _report.reportId);

      if (!mounted) return;

      setState(() {
        _report = _report.copyWith(
          status: newStatus,
          verifiedBy: newStatus == 'active' ? currentUserId : _report.verifiedBy,
          verifiedAt: newStatus == 'active' ? DateTime.now() : _report.verifiedAt,
        );
        _isSubmitting = false;
      });

      widget.onReportUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'active'
                ? 'Report accepted! Hazard is now active on the map.'
                : 'Report status updated to $newStatus.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: newStatus == 'active'
              ? const Color(0xFF1A7A45)
              : const Color(0xFF1F3A5F),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Error updating report status: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update report status: $e',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFFD4F5E5);
      case 'pending':
        return const Color(0xFFFDF0DC);
      case 'resolved':
        return const Color(0xFFE8F4FB);
      case 'rejected':
      case 'archived':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF0F4F8);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF1A7A45);
      case 'pending':
        return const Color(0xFFC17F24);
      case 'resolved':
        return const Color(0xFF1976D2);
      case 'rejected':
      case 'archived':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF5B6B7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.92).clamp(320.0, 560.0);
    final maxHeight = mediaQuery.size.height * 0.88;

    final statusBg = _getStatusBackgroundColor(_report.status);
    final statusText = _getStatusTextColor(_report.status);
    final isPending = _report.status.toLowerCase() == 'pending';
    final isActive = _report.status.toLowerCase() == 'active';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8EDF2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _report.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: statusText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _report.detectedHazard,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2B4A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF5B6B7A)),
                    onPressed: () => Navigator.of(context).pop(false),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Picture
                    _buildImageSection(_report.imageUrl),
                    const SizedBox(height: 18),

                    // Place & Location Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF1F3A5F),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Name',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF7B9BAD),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _report.locationAddress,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A2B4A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_report.latitude != null && _report.longitude != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Coordinates: ${_report.latitude!.toStringAsFixed(5)}, ${_report.longitude!.toStringAsFixed(5)}',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8A94A6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // The One Who Reported It
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3FAF6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF1A7A45),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reported By',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF7B9BAD),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _report.reporterName,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A2B4A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_report.reporterEmail != null &&
                                  _report.reporterEmail!.isNotEmpty)
                                Text(
                                  _report.reporterEmail!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8A94A6),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Timestamp & Hazard Details row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EEF2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF7B9BAD),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _report.hazardCategory,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1A2B4A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: const Color(0xFFE0E6ED),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reported Time',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF7B9BAD),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatRelativeTime(_report.createdAt),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1A2B4A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Description Section
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1A2B4A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8ED)),
                      ),
                      child: Text(
                        _report.description.trim().isNotEmpty
                            ? _report.description.trim()
                            : 'No additional description provided.',
                        style: GoogleFonts.inter(
                          color: _report.description.trim().isNotEmpty
                              ? const Color(0xFF2D3748)
                              : const Color(0xFF8A94A6),
                          fontSize: 13,
                          height: 1.45,
                          fontStyle: _report.description.trim().isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Bottom Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE8EDF2), width: 1),
                ),
              ),
              child: _isSubmitting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPending) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _updateStatus('rejected'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE53935),
                                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Reject Report',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateStatus('active'),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: Text(
                                    'Accept Report',
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
                          ),
                        ] else ...[
                          Row(
                            children: [
                              if (isActive)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus('resolved'),
                                    icon: const Icon(Icons.done_all, size: 16),
                                    label: Text(
                                      'Mark Resolved',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1976D2),
                                      side: const BorderSide(color: Color(0xFFBBDEFB)),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isActive) const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(false),
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
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String? imageUrl) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF0F4F7),
          border: Border.all(color: const Color(0xFFE2E8ED)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl.trim(),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2.5,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    size: 38,
                    color: Color(0xFF8A94A6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unable to load photo',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8A94A6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8ED)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 32,
              color: Color(0xFFA0AEC0),
            ),
            const SizedBox(height: 6),
            Text(
              'No photo attached to this report',
              style: GoogleFonts.inter(
                color: const Color(0xFFA0AEC0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
