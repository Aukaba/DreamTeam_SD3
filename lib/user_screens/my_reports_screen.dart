import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../map_screen.dart';
import '../services/hazard_report_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/report_hazard_modal.dart';

class MyReportsScreen extends StatefulWidget {
  final HazardReportService? hazardReportService;

  const MyReportsScreen({
    super.key,
    this.hazardReportService,
  });

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  static const Color _primaryNavy = Color(0xFF233253);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _bgBeige = Color(0xFFFAF8F5);
  static const Color _accentBlue = Color(0xFF1E6FD9);
  static const Color _lightBlue = Color(0xFFEBF3FC);

  late final HazardReportService _hazardReportService;
  StreamSubscription<HazardReportData>? _reportSubscription;
  StreamSubscription<HazardResolutionReportData>? _resolutionSubscription;
  RealtimeChannel? _remoteReportsChannel;

  List<HazardReportData> _reports = const <HazardReportData>[];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Active, Resolved, High, Medium, Low

  @override
  void initState() {
    super.initState();
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _loadUserReports();
    _reportSubscription = HazardReportService.reportStream.listen((_) {
      _loadUserReports();
    });
    _resolutionSubscription = HazardReportService.resolutionStream.listen((_) {
      _loadUserReports();
    });
    _remoteReportsChannel = _hazardReportService.subscribeToRemoteReportChanges(
      onReportChanged: () {
        if (mounted) {
          _loadUserReports();
        }
      },
    );
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _resolutionSubscription?.cancel();
    if (_remoteReportsChannel != null) {
      _hazardReportService
          .unsubscribeFromRemoteReportChanges(_remoteReportsChannel);
    }
    super.dispose();
  }

  int _fetchGeneration = 0;

  Future<void> _loadUserReports() async {
    final fetchGen = ++_fetchGeneration;
    if (mounted && _reports.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final fetched = await _hazardReportService.fetchUserReports();
      if (!mounted || fetchGen != _fetchGeneration) return;
      setState(() {
        // Only count & show accepted reports ('active' or 'resolved')
        _reports = fetched
            .where(
              (r) => HazardReportStatuses.isAcceptedForUserReports(r.status),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || fetchGen != _fetchGeneration) return;
      setState(() => _isLoading = false);
    }
  }

  List<HazardReportData> get _filteredReports {
    switch (_selectedFilter) {
      case 'Active':
        return _reports.where((r) => r.status == 'active').toList();
      case 'Resolved':
        return _reports.where((r) => r.status == 'resolved').toList();
      case 'High':
        return _reports
            .where((r) => r.securityLevel.toLowerCase() == 'high')
            .toList();
      case 'Medium':
        return _reports
            .where((r) => r.securityLevel.toLowerCase() == 'medium')
            .toList();
      case 'Low':
        return _reports
            .where((r) => r.securityLevel.toLowerCase() == 'low')
            .toList();
      case 'All':
      default:
        return _reports;
    }
  }

  int get _totalPoints {
    int sum = 0;
    for (final r in _reports) {
      sum += r.pointsAwarded;
    }
    return sum;
  }

  Future<void> _confirmDeleteReport(HazardReportData report) async {
    final reportId = report.reportId;
    if (reportId == null || reportId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Report',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${report.title}"?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: _secondaryGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9383A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _hazardReportService.deleteUserReport(reportId);
      await _loadUserReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete report: $e'),
          backgroundColor: const Color(0xFFD9383A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openReportOnMap(HazardReportData report) {
    final loc = report.location;
    if (loc == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: loc,
          focusHazardLocation: loc,
          focusedReportId: report.reportId,
          hazardReportService: _hazardReportService,
        ),
      ),
    );
  }

  void _openNewReportModal() {
    showReportHazardModal(
      context,
      onReportSubmitted: (_) {
        if (mounted) {
          _loadUserReports();
        }
      },
    );
  }

  ({Color bg, Color text, IconData icon}) _severityBadgeStyle(String severity) {
    switch (severity.trim().toLowerCase()) {
      case 'high':
        return (
          bg: const Color(0xFFFFEBEE),
          text: const Color(0xFFC62828),
          icon: Icons.error_outline_rounded,
        );
      case 'medium':
        return (
          bg: const Color(0xFFFFF8E1),
          text: const Color(0xFFF57F17),
          icon: Icons.warning_amber_rounded,
        );
      case 'low':
      default:
        return (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelProgress = LevelProgressData.fromTotalPoints(_totalPoints);
    final filtered = _filteredReports;

    return Scaffold(
      backgroundColor: _bgBeige,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryNavy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Reports',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Submit a new report',
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: _accentBlue,
            ),
            onPressed: _openNewReportModal,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primaryNavy,
        onRefresh: _loadUserReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(18),
          children: [
            _buildSummaryHeaderCard(levelProgress),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: _primaryNavy),
                ),
              )
            else if (filtered.isEmpty)
              _buildEmptyState()
            else
              ...filtered.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildReportCard(report),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeaderCard(LevelProgressData levelProgress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3765),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  value: '${_reports.length}',
                  label: 'Submitted Reports',
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  value: '$_totalPoints pts',
                  label: 'Points Earned',
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  value: 'Level ${levelProgress.level}',
                  label:
                      '${levelProgress.currentLevelPoints}/${levelProgress.nextLevelRequiredPoints} pts',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFFF7D046),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Points by severity: Low +1 pt · Medium +2 pts · High +3 pts',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    const filters = <String>[
      'All',
      'Active',
      'Resolved',
      'High',
      'Medium',
      'Low',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : _primaryNavy,
                ),
              ),
              selected: isSelected,
              selectedColor: _primaryNavy,
              backgroundColor: Colors.white,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? _primaryNavy
                      : const Color(0xFFE2E8F0),
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  ({Color bg, Color text, IconData icon, String label}) _statusBadgeStyle(
    String rawStatus,
  ) {
    final normalized = HazardReportStatuses.normalize(rawStatus);
    switch (normalized) {
      case HazardReportStatuses.pending:
        return (
          bg: const Color(0xFFFFF8E1),
          text: const Color(0xFFB45309),
          icon: Icons.hourglass_top_rounded,
          label: 'Pending - Needs Verification',
        );
      case HazardReportStatuses.active:
        return (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
          icon: Icons.visibility_rounded,
          label: 'Active - Shown on Map',
        );
      case HazardReportStatuses.resolved:
        return (
          bg: const Color(0xFFF1F5F9),
          text: const Color(0xFF475569),
          icon: Icons.check_circle_outline_rounded,
          label: 'Resolved',
        );
      default:
        return (
          bg: const Color(0xFFF1F5F9),
          text: _secondaryGrey,
          icon: Icons.info_outline_rounded,
          label: HazardReportStatuses.labelFor(normalized),
        );
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: _accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedFilter == 'All'
                ? 'No submitted reports yet'
                : 'No $_selectedFilter reports found',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'When you report road hazards in your community, they will appear here along with the points earned.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _secondaryGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openNewReportModal,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Report a Hazard',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(HazardReportData report) {
    final severityStyle = _severityBadgeStyle(report.securityLevel);
    final statusStyle = _statusBadgeStyle(report.status);
    final isActive = report.status == 'active';
    final hasPendingResolution = report.resolutionStatus == 'pending' ||
        (report.reportId != null &&
            HazardReportService.hasPendingResolution(report.reportId));
    final cleanCategory = HazardReportService.cleanCategory(report.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges row: Severity, Points Earned, Status, Timestamp
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Severity Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityStyle.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      severityStyle.icon,
                      size: 12,
                      color: severityStyle.text,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${report.securityLevel} Severity',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: severityStyle.text,
                      ),
                    ),
                  ],
                ),
              ),

              // Points Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${report.pointsAwarded} ${report.pointsAwarded == 1 ? 'pt' : 'pts'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _accentBlue,
                  ),
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusStyle.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusStyle.icon,
                      size: 11,
                      color: statusStyle.text,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusStyle.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusStyle.text,
                      ),
                    ),
                  ],
                ),
              ),

              if (hasPendingResolution && report.status != 'resolved')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Resolution Pending Verification',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),

              Text(
                HazardReportService.formatRelativeTime(report.timestamp),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  color: _secondaryGrey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Title & Category
          Text(
            report.title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cleanCategory,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _accentBlue,
            ),
          ),

          if (report.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: _secondaryGrey,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Location address row
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: _secondaryGrey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _secondaryGrey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F6)),
          const SizedBox(height: 6),

          // Actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (report.location != null && isActive)
                TextButton.icon(
                  onPressed: () => _openReportOnMap(report),
                  icon: const Icon(
                    Icons.map_outlined,
                    size: 15,
                    color: _accentBlue,
                  ),
                  label: const Text(
                    'View on Map',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _accentBlue,
                    ),
                  ),
                ),
              if (report.reportId != null && report.reportId!.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmDeleteReport(report),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Color(0xFFD9383A),
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD9383A),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
