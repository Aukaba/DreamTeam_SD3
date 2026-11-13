import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_profile_screen.dart';
import 'admin_report_detail_modal.dart';
import 'admin_resolution_modal.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedSection = 0; // 0 = Hazard Reports, 1 = Mark to Resolve
  List<AdminReportItem> _allReports = <AdminReportItem>[];
  List<AdminReportItem> _filteredReports = <AdminReportItem>[];
  List<AdminResolutionItem> _allResolutions = <AdminResolutionItem>[];
  List<AdminResolutionItem> _filteredResolutions = <AdminResolutionItem>[];
  bool _isLoading = true;
  String? _error;
  String _selectedStatusFilter = 'all'; // 'all', 'pending', 'active', 'resolved'
  String _selectedResolutionStatusFilter = 'all'; // 'all', 'pending', 'resolved', 'rejected'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      // 1. Fetch all rows from ReportTable ordered by newest first
      final dynamic rawReports = await client
          .from('ReportTable')
          .select()
          .order('created_at', ascending: false);

      // 1b. Fetch all rows from hazard_resolution_reports ordered by newest first
      dynamic rawResolutions;
      try {
        rawResolutions = await client
            .from('hazard_resolution_reports')
            .select()
            .order('created_at', ascending: false);
      } catch (resErr) {
        debugPrint('Warning: Could not fetch hazard_resolution_reports: $resErr');
      }

      final List<Map<String, dynamic>> reportRows = [];
      final List<Map<String, dynamic>> resolutionRows = [];
      final Set<String> userIds = <String>{};

      if (rawReports is List) {
        for (final item in rawReports) {
          if (item is Map<String, dynamic>) {
            reportRows.add(item);
            final uid = item['user_id']?.toString().trim();
            if (uid != null && uid.isNotEmpty) {
              userIds.add(uid);
            }
          }
        }
      }

      if (rawResolutions is List) {
        for (final item in rawResolutions) {
          if (item is Map<String, dynamic>) {
            resolutionRows.add(item);
            final rby = item['reported_by']?.toString().trim();
            if (rby != null && rby.isNotEmpty) {
              userIds.add(rby);
            }
          }
        }
      }

      // 2. Fetch associated profiles for reporter names and avatars
      final Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final dynamic profilesData = await client
              .from('profiles')
              .select('id, full_name, username, email, avatar_url')
              .inFilter('id', userIds.toList());

          if (profilesData is List) {
            for (final p in profilesData) {
              if (p is Map<String, dynamic> && p['id'] != null) {
                profilesMap[p['id'].toString()] = p;
              }
            }
          }
        } catch (profileErr) {
          debugPrint('Warning: Could not fetch reporter profiles: $profileErr');
        }
      }

      // 2b. Fetch admin profile for verifier information
      Map<String, dynamic>? adminProfile;
      try {
        final dynamic adminData = await client
            .from('profiles')
            .select('id, full_name, username, email, role')
            .eq('role', 'admin')
            .maybeSingle();
        if (adminData is Map<String, dynamic>) {
          adminProfile = adminData;
        }
      } catch (adminErr) {
        debugPrint('Warning: Could not fetch admin profile: $adminErr');
      }

      // 3. Map to AdminReportItem list
      final parsedReports = reportRows.map((row) {
        final uid = row['user_id']?.toString().trim();
        final profile = uid != null ? profilesMap[uid] : null;
        return AdminReportItem.fromRow(row, profile: profile);
      }).toList();

      // 3b. Map to AdminResolutionItem list
      final parsedResolutions = resolutionRows.map((row) {
        final rby = row['reported_by']?.toString().trim();
        final reporterProfile = rby != null ? profilesMap[rby] : null;
        return AdminResolutionItem.fromRow(
          row,
          reporterProfile: reporterProfile,
          adminProfile: adminProfile,
        );
      }).toList();

      // Prioritize pending resolutions at the top, then newest first
      parsedResolutions.sort((a, b) {
        final aPending = a.status.toLowerCase() == 'pending';
        final bPending = b.status.toLowerCase() == 'pending';
        if (aPending && !bPending) return -1;
        if (!aPending && bPending) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) return;
      setState(() {
        _allReports = parsedReports;
        _allResolutions = parsedResolutions;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports. Please pull down to refresh.';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredReports = _allReports.where((report) {
        // Status filter
        if (_selectedStatusFilter != 'all') {
          if (report.status.toLowerCase() != _selectedStatusFilter) {
            return false;
          }
        }

        // Search query filter
        if (query.isNotEmpty) {
          final matchesHazard =
              report.detectedHazard.toLowerCase().contains(query);
          final matchesCategory =
              report.hazardCategory.toLowerCase().contains(query);
          final matchesLocation =
              report.locationAddress.toLowerCase().contains(query);
          final matchesReporter =
              report.reporterName.toLowerCase().contains(query);
          final matchesDescription =
              report.description.toLowerCase().contains(query);

          return matchesHazard ||
              matchesCategory ||
              matchesLocation ||
              matchesReporter ||
              matchesDescription;
        }

        return true;
      }).toList();

      _filteredResolutions = _allResolutions.where((res) {
        // Status filter
        if (_selectedResolutionStatusFilter != 'all') {
          final s = res.status.toLowerCase();
          if (_selectedResolutionStatusFilter == 'resolved') {
            if (s != 'resolved' && s != 'approved') return false;
          } else if (s != _selectedResolutionStatusFilter) {
            return false;
          }
        }

        // Search query filter
        if (query.isNotEmpty) {
          final matchesHazard =
              res.detectedHazard.toLowerCase().contains(query);
          final matchesCategory =
              res.hazardCategory.toLowerCase().contains(query);
          final matchesLocation =
              res.locationAddress.toLowerCase().contains(query);
          final matchesReporter =
              res.reporterName.toLowerCase().contains(query);
          final matchesNote =
              res.resolutionNote.toLowerCase().contains(query);

          return matchesHazard ||
              matchesCategory ||
              matchesLocation ||
              matchesReporter ||
              matchesNote;
        }

        return true;
      }).toList();
    });
  }

  void _onStatusFilterSelected(String status) {
    if (_selectedStatusFilter == status) return;
    setState(() {
      _selectedStatusFilter = status;
    });
    _applyFilters();
  }

  void _onResolutionStatusFilterSelected(String status) {
    if (_selectedResolutionStatusFilter == status) return;
    setState(() {
      _selectedResolutionStatusFilter = status;
    });
    _applyFilters();
  }

  void _openReportDetail(AdminReportItem report) async {
    final updated = await showAdminReportDetailModal(
      context: context,
      report: report,
      onReportUpdated: _loadReports,
    );
    if (updated == true) {
      _loadReports();
    }
  }

  void _openResolutionDetail(AdminResolutionItem resolution) async {
    final updated = await showAdminResolutionDetailModal(
      context: context,
      resolution: resolution,
      onResolutionUpdated: _loadReports,
    );
    if (updated == true) {
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/image/saferoute_admin_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isSmallScreen = screenWidth < 360;
                final isTablet = screenWidth >= 600;
                final isDesktop = screenWidth >= 1200;

                final pendingResolutionsCount = _allResolutions
                    .where((r) => r.status.toLowerCase() == 'pending')
                    .length;

                return RefreshIndicator(
                  onRefresh: _loadReports,
                  color: const Color(0xFF1F3A5F),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0),
                        vertical: isDesktop ? 32.0 : 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isSmallScreen, isTablet, isDesktop, context),
                          SizedBox(height: isDesktop ? 32 : 24),
                          _buildGreeting(isSmallScreen, isTablet, isDesktop),
                          SizedBox(height: isDesktop ? 20 : 16),
                          _buildSectionSwitcher(
                            isSmallScreen: isSmallScreen,
                            isTablet: isTablet,
                            isDesktop: isDesktop,
                            pendingResolutionsCount: pendingResolutionsCount,
                          ),
                          if (_selectedSection == 0 && pendingResolutionsCount > 0) ...[
                            const SizedBox(height: 12),
                            _buildPendingResolutionBanner(
                              count: pendingResolutionsCount,
                              isSmallScreen: isSmallScreen,
                            ),
                          ],
                          SizedBox(height: isDesktop ? 20 : 16),
                          _buildSearchBar(isSmallScreen, isTablet, isDesktop),
                          const SizedBox(height: 16),
                          _selectedSection == 0
                              ? _buildStatusFilters(isSmallScreen, isTablet, isDesktop)
                              : _buildResolutionStatusFilters(isSmallScreen, isTablet, isDesktop),
                          SizedBox(height: isDesktop ? 24 : 16),
                          _selectedSection == 0
                              ? _buildReportsList(isSmallScreen, isTablet, isDesktop)
                              : _buildResolutionsList(isSmallScreen, isTablet, isDesktop),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      bool isSmallScreen, bool isTablet, bool isDesktop, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 1,
                    color: const Color(0xFFE8EEF2),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Color(0xFF1F3A5F),
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 20 : 14),
            Image.asset(
              'assets/image/LogoSR.png',
              width: 43,
              height: 47,
            ),
            SizedBox(width: isDesktop ? 20 : 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Safe',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF45596E),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: 'Route',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8AABCE),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FB),
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 1,
                    color: const Color(0xFFD0E8F5),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Color(0xFF5B6B7A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreeting(bool isSmallScreen, bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage & Review Reports',
          style: GoogleFonts.inter(
            color: const Color(0xFF7B9BAD),
            fontSize: isDesktop ? 15 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        Text(
          'All Community Reports',
          style: GoogleFonts.inter(
            color: const Color(0xFF1A2B4A),
            fontSize: isDesktop ? 30 : 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isSmallScreen, bool isTablet, bool isDesktop) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          width: 1,
          color: const Color(0xFFE2E8ED),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by hazard, location, or reporter...',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFA8BFCA),
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFFA8BFCA),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFFA8BFCA)),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.inter(
          color: const Color(0xFF1A2B4A),
          fontSize: isDesktop ? 14 : 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSectionSwitcher({
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    required int pendingResolutionsCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedSection == 0) return;
                setState(() => _selectedSection = 0);
                _applyFilters();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedSection == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 16,
                      color: _selectedSection == 0
                          ? const Color(0xFF1F3A5F)
                          : const Color(0xFF7B9BAD),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hazard Reports (${_allReports.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 11 : 12.5,
                          fontWeight: _selectedSection == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedSection == 0
                              ? const Color(0xFF1F3A5F)
                              : const Color(0xFF7B9BAD),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedSection == 1) return;
                setState(() => _selectedSection = 1);
                _applyFilters();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedSection == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 16,
                      color: _selectedSection == 1
                          ? const Color(0xFF1976D2)
                          : const Color(0xFF7B9BAD),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Mark to Resolve',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 11 : 12.5,
                          fontWeight: _selectedSection == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedSection == 1
                              ? const Color(0xFF1A2B4A)
                              : const Color(0xFF7B9BAD),
                        ),
                      ),
                    ),
                    if (pendingResolutionsCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingResolutionsCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingResolutionBanner({
    required int count,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count user${count == 1 ? '' : 's'} reported a hazard as resolved.',
              style: GoogleFonts.inter(
                color: const Color(0xFF9A3412),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => _selectedSection = 1);
              _applyFilters();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Review',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD97706),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward,
                      size: 13, color: Color(0xFFD97706)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionStatusFilters(
      bool isSmallScreen, bool isTablet, bool isDesktop) {
    final pendingCount = _allResolutions
        .where((r) => r.status.toLowerCase() == 'pending')
        .length;
    final resolvedCount = _allResolutions
        .where((r) =>
            r.status.toLowerCase() == 'resolved' ||
            r.status.toLowerCase() == 'approved')
        .length;
    final rejectedCount = _allResolutions
        .where((r) => r.status.toLowerCase() == 'rejected')
        .length;

    final filters = [
      {'key': 'all', 'label': 'All (${_allResolutions.length})'},
      {'key': 'pending', 'label': 'Pending ($pendingCount)'},
      {'key': 'resolved', 'label': 'Resolved ($resolvedCount)'},
      {'key': 'rejected', 'label': 'Rejected ($rejectedCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedResolutionStatusFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF5B6B7A),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: const Color(0xFF1F3A5F),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1F3A5F)
                      : const Color(0xFFE2E8ED),
                ),
              ),
              onSelected: (_) => _onResolutionStatusFilterSelected(f['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilters(bool isSmallScreen, bool isTablet, bool isDesktop) {
    final pendingCount =
        _allReports.where((r) => r.status.toLowerCase() == 'pending').length;
    final activeCount =
        _allReports.where((r) => r.status.toLowerCase() == 'active').length;
    final resolvedCount =
        _allReports.where((r) => r.status.toLowerCase() == 'resolved').length;

    final filters = [
      {'key': 'all', 'label': 'All (${_allReports.length})'},
      {'key': 'pending', 'label': 'Pending ($pendingCount)'},
      {'key': 'active', 'label': 'Active ($activeCount)'},
      {'key': 'resolved', 'label': 'Resolved ($resolvedCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedStatusFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF5B6B7A),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: const Color(0xFF1F3A5F),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1F3A5F)
                      : const Color(0xFFE2E8ED),
                ),
              ),
              onSelected: (_) => _onStatusFilterSelected(f['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportsList(bool isSmallScreen, bool isTablet, bool isDesktop) {
    if (_isLoading) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF1F3A5F),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading reports from database...',
              style: GoogleFonts.inter(
                color: const Color(0xFF7B9BAD),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFE53935)),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(
                color: const Color(0xFF5B6B7A),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F3A5F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 48,
              color: Color(0xFFA8BFCA),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No matching reports found'
                  : 'No reports found in this category',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2B4A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try searching with different keywords.'
                  : 'Submitted reports will show up here for verification.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7B9BAD),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _filteredReports.map((report) {
        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 20 : 14),
          child: _buildReportCard(
            report: report,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            onTap: () => _openReportDetail(report),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReportCard({
    required AdminReportItem report,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    final imageSize = isDesktop ? 96.0 : (isSmallScreen ? 68.0 : 76.0);
    final spacing = isDesktop ? 20.0 : 14.0;
    final padding = isDesktop ? 20.0 : 14.0;

    final isPending = report.status.toLowerCase() == 'pending';
    final isActive = report.status.toLowerCase() == 'active';

    Color statusBgColor;
    Color statusTextColor;
    if (isActive) {
      statusBgColor = const Color(0xFFD4F5E5);
      statusTextColor = const Color(0xFF1A7A45);
    } else if (isPending) {
      statusBgColor = const Color(0xFFFDF0DC);
      statusTextColor = const Color(0xFFC17F24);
    } else if (report.status.toLowerCase() == 'resolved') {
      statusBgColor = const Color(0xFFE8F4FB);
      statusTextColor = const Color(0xFF1976D2);
    } else {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFD32F2F);
    }

    final hasImage =
        report.imageUrl != null && report.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 1,
              color: isPending ? const Color(0xFFFFE0B2) : const Color(0xFFE8EDF2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Report Image Preview
              SizedBox(
                width: imageSize,
                height: imageSize,
                child: Stack(
                  children: [
                    Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFE8F4FB),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? Image.network(
                              report.imageUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.report_problem,
                                    size: 30,
                                    color: Color(0xFF1F3A5F),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.report_problem,
                                size: 30,
                                color: Color(0xFF1F3A5F),
                              ),
                            ),
                    ),
                    // Status Badge Icon
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isPending
                              ? const Color(0xFFE53935)
                              : const Color(0xFF2ECC71),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Icon(
                            isPending ? Icons.priority_high : Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),

              // Report Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            report.detectedHazard,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1A2B4A),
                              fontSize: isDesktop ? 16 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: statusTextColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Location Name / Address
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF7B9BAD),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.locationAddress,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF5B6B7A),
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // The One Who Reported It
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Color(0xFF7B9BAD),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Reported by: ${report.reporterName}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7B9BAD),
                              fontSize: isDesktop ? 11.5 : 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Timestamp
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFFA0AEC0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatRelativeTime(report.createdAt),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA0AEC0),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Color(0xFF1F3A5F),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionsList(
      bool isSmallScreen, bool isTablet, bool isDesktop) {
    if (_isLoading) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF1F3A5F),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading resolution requests...',
              style: GoogleFonts.inter(
                color: const Color(0xFF7B9BAD),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredResolutions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.task_alt,
              size: 48,
              color: Color(0xFFA8BFCA),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No matching resolution requests'
                  : 'No resolution requests found',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2B4A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try searching with different keywords.'
                  : 'When users submit camera proof that a hazard was resolved, it will appear here for your review.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7B9BAD),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _filteredResolutions.map((resolution) {
        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 20 : 14),
          child: _buildResolutionCard(
            resolution: resolution,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            onTap: () => _openResolutionDetail(resolution),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResolutionCard({
    required AdminResolutionItem resolution,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    final imageSize = isDesktop ? 96.0 : (isSmallScreen ? 68.0 : 76.0);
    final spacing = isDesktop ? 20.0 : 14.0;
    final padding = isDesktop ? 20.0 : 14.0;

    final isPending = resolution.status.toLowerCase() == 'pending';
    final isResolved = resolution.status.toLowerCase() == 'resolved' ||
        resolution.status.toLowerCase() == 'approved';

    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;
    if (isResolved) {
      statusBgColor = const Color(0xFFD4F5E5);
      statusTextColor = const Color(0xFF1A7A45);
      statusLabel = 'RESOLVED';
    } else if (isPending) {
      statusBgColor = const Color(0xFFFFF4E5);
      statusTextColor = const Color(0xFFD97706);
      statusLabel = 'PENDING REVIEW';
    } else {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFE53935);
      statusLabel = 'REJECTED';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 1,
              color: isPending
                  ? const Color(0xFFFFD59E)
                  : const Color(0xFFE8EDF2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resolution Photo Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      color: const Color(0xFFF4F7F9),
                      child: resolution.resolutionImageUrl.isNotEmpty
                          ? Image.network(
                              resolution.resolutionImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.camera_alt_outlined,
                                color: Color(0xFFA8BFCA),
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Color(0xFFA8BFCA),
                              size: 28,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xA6000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PROOF',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(width: spacing),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resolution.detectedHazard,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1A2B4A),
                              fontSize: isDesktop ? 16 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              color: statusTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Location Address
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF7B9BAD),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            resolution.locationAddress,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7B9BAD),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Reported resolved by
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Color(0xFF5B6B7A),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Marked resolved by ${resolution.reporterName}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF5B6B7A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (resolution.resolutionNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${resolution.resolutionNote}"',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7B9BAD),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Timestamp
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFFA0AEC0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatRelativeTime(resolution.createdAt),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA0AEC0),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Color(0xFF1F3A5F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
