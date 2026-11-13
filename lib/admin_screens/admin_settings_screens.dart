import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_analytics_service.dart';
import 'admin_reports_screen.dart';

Widget _buildAdminPageScaffold({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Widget child,
}) {
  return Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
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
            final horizontalPadding = isDesktop
                ? 48.0
                : (isTablet ? 32.0 : (isSmallScreen ? 12.0 : 16.0));

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isDesktop ? 32.0 : 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.of(context).maybePop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
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
                            const SizedBox(width: 14),
                            Image.asset(
                              'assets/image/LogoSR.png',
                              width: 40,
                              height: 44,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text.rich(
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF738297),
                            fontSize: isDesktop ? 15 : 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1E2A41),
                            fontSize:
                                isDesktop ? 30 : (isSmallScreen ? 22 : 26),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

BoxDecoration _adminCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFEDF3F8)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 15,
        offset: Offset(0, 4),
      ),
    ],
  );
}

class AdminAccountInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  final Future<void> Function(String fullName)? onSaveFullName;

  const AdminAccountInfoScreen({
    super.key,
    this.initialProfile,
    this.onSaveFullName,
  });

  @override
  State<AdminAccountInfoScreen> createState() => _AdminAccountInfoScreenState();
}

class _AdminAccountInfoScreenState extends State<AdminAccountInfoScreen> {
  late final TextEditingController _fullNameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: (widget.initialProfile?['full_name'] as String?) ?? 'Admin',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final trimmedName = _fullNameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorMessage = 'Full name cannot be empty.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.onSaveFullName != null) {
        await widget.onSaveFullName!(trimmedName);
      } else {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        await supabase
            .from('profiles')
            .update({'full_name': trimmedName})
            .eq('id', user.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account information updated.')),
      );
      Navigator.of(context).pop(trimmedName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to update account details. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        (widget.initialProfile?['email'] as String?) ?? 'admin@saferoute.ph';

    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Admin Profile',
      title: 'Account Information',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _adminCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Full Name',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2A41),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF6F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Email Address',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2A41),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                email,
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B6B7A),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Assigned Role',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2A41),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Administrator (Server Verified)',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5A88C5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD95379),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F3A5F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSafetySettingsScreen extends StatefulWidget {
  const AdminSafetySettingsScreen({super.key});

  @override
  State<AdminSafetySettingsScreen> createState() =>
      _AdminSafetySettingsScreenState();
}

class _AdminSafetySettingsScreenState extends State<AdminSafetySettingsScreen> {
  bool _instantCriticalAlerts = true;
  bool _pendingReportReminders = true;
  bool _autoFlagLowConfidence = true;
  double _confidenceThreshold = 80;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _instantCriticalAlerts =
          prefs.getBool('admin_instant_critical_alerts') ?? true;
      _pendingReportReminders =
          prefs.getBool('admin_pending_report_reminders') ?? true;
      _autoFlagLowConfidence =
          prefs.getBool('admin_auto_flag_low_confidence') ?? true;
      _confidenceThreshold =
          prefs.getDouble('admin_confidence_threshold') ?? 80;
      _isLoaded = true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'admin_instant_critical_alerts',
      _instantCriticalAlerts,
    );
    await prefs.setBool(
      'admin_pending_report_reminders',
      _pendingReportReminders,
    );
    await prefs.setBool(
      'admin_auto_flag_low_confidence',
      _autoFlagLowConfidence,
    );
    await prefs.setDouble('admin_confidence_threshold', _confidenceThreshold);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safety settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Admin Configuration',
      title: 'Safety Settings',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _adminCardDecoration(),
        child: !_isLoaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF1F3A5F),
                    title: Text(
                      'High-Severity Hazard Alerts',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E2A41),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Notify immediately when a high-risk road hazard is submitted.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF738297),
                        fontSize: 12,
                      ),
                    ),
                    value: _instantCriticalAlerts,
                    onChanged: (val) =>
                        setState(() => _instantCriticalAlerts = val),
                  ),
                  const Divider(color: Color(0xFFF0F4F8)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF1F3A5F),
                    title: Text(
                      'Pending Verification Reminders',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E2A41),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Send periodic reminders when unverified reports exceed 30 minutes.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF738297),
                        fontSize: 12,
                      ),
                    ),
                    value: _pendingReportReminders,
                    onChanged: (val) =>
                        setState(() => _pendingReportReminders = val),
                  ),
                  const Divider(color: Color(0xFFF0F4F8)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF1F3A5F),
                    title: Text(
                      'Auto-Flag Low AI Confidence Reports',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E2A41),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Queue reports below the confidence threshold for manual review.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF738297),
                        fontSize: 12,
                      ),
                    ),
                    value: _autoFlagLowConfidence,
                    onChanged: (val) =>
                        setState(() => _autoFlagLowConfidence = val),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Verification Threshold: ${_confidenceThreshold.round()}%',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1E2A41),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Slider(
                    value: _confidenceThreshold,
                    min: 60,
                    max: 95,
                    divisions: 7,
                    activeColor: const Color(0xFF1F3A5F),
                    label: '${_confidenceThreshold.round()}%',
                    onChanged: (val) =>
                        setState(() => _confidenceThreshold = val),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Preferences',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AdminAnalyticsScreen extends StatefulWidget {
  final AdminAnalyticsRawSnapshot? initialSnapshot;
  final Future<AdminAnalyticsRawSnapshot> Function()? analyticsLoader;

  const AdminAnalyticsScreen({
    super.key,
    this.initialSnapshot,
    this.analyticsLoader,
  });

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  static const Color _navy = Color(0xFF1F3A5F);
  static const Color _teal = Color(0xFF61B5AB);
  static const Color _muted = Color(0xFF5B6B7A);

  BoxDecoration _analyticsCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(width: 1, color: const Color(0xFFD9E2EC)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x121F3A5F),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  AnalyticsTimeframe _selectedTimeframe = AnalyticsTimeframe.allTime;
  AdminAnalyticsRawSnapshot? _snapshot;
  late AdminSafetyAnalytics _analytics;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _analytics = _snapshot != null
        ? _snapshot!.compute(timeframe: _selectedTimeframe)
        : AdminSafetyAnalytics.empty(timeframe: _selectedTimeframe);
    if (_snapshot != null) {
      _isLoading = false;
    }
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final fetched = widget.analyticsLoader != null
          ? await widget.analyticsLoader!()
          : await const AdminAnalyticsService().fetchRawSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = fetched;
        _analytics = fetched.compute(timeframe: _selectedTimeframe);
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('Error loading AdminAnalyticsScreen data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = _snapshot == null;
      });
    }
  }

  void _selectTimeframe(AnalyticsTimeframe timeframe) {
    if (_selectedTimeframe == timeframe) return;
    setState(() {
      _selectedTimeframe = timeframe;
      if (_snapshot != null) {
        _analytics = _snapshot!.compute(timeframe: timeframe);
      }
    });
  }

  void _openReportManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminReportsScreen(),
      ),
    ).then((_) => _loadAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Hazard Operations & Safety Insights',
      title: 'Analytics Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeframeAndStatusHeader(),
          const SizedBox(height: 16),
          if (_isLoading && _snapshot == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: _adminCardDecoration(),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _navy,
                ),
              ),
            )
          else ...[
            if (_loadFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Unable to reach live database right now. Tap refresh to retry.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            _buildKpiSummaryGrid(),
            const SizedBox(height: 16),
            _buildSevenDayVelocityCard(),
            const SizedBox(height: 16),
            _buildCategoryAndPipelineCard(),
            const SizedBox(height: 16),
            _buildHotspotsCard(),
            const SizedBox(height: 16),
            _buildAiAndResolutionQualityCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeframeAndStatusHeader() {
    final riskLabel = _analytics.overallRiskLabel;
    final bool isHighRisk = _analytics.activeHighCount >= 1;
    final Color riskBg = _analytics.activeHazardsCount == 0
        ? const Color(0xFFE8F7F0)
        : (isHighRisk ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    final Color riskFg = _analytics.activeHazardsCount == 0
        ? const Color(0xFF047857)
        : (isHighRisk ? const Color(0xFFB91C1C) : const Color(0xFFB45309));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _analyticsCardDecoration(),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AnalyticsTimeframe.values.map((tf) {
              final selected = _selectedTimeframe == tf;
              return InkWell(
                onTap: () => _selectTimeframe(tf),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _navy : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tf.displayLabel,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : _navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: riskFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      riskLabel,
                      style: GoogleFonts.inter(
                        color: riskFg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _loadAnalytics,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF4F8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 17,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryGrid() {
    final active = _analytics.activeHazardsCount;
    final severitySummary =
        '${_analytics.activeHighCount} High · ${_analytics.activeMediumCount} Med · ${_analytics.activeLowCount} Low';
    final resRate = _analytics.hasResolutionDenominator
        ? '${_analytics.resolutionRatePercent}%'
        : '—';

    final cards = <Widget>[
      _AnalyticsOverviewKpiCard(
        title: 'Active Hazards on Map',
        value: '$active',
        subtitle: severitySummary,
        icon: Icons.warning_amber_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        decoration: _analyticsCardDecoration(),
      ),
      InkWell(
        onTap: _openReportManagement,
        borderRadius: BorderRadius.circular(16),
        child: _AnalyticsOverviewKpiCard(
          title: 'Pending Review Queue',
          value: '${_analytics.totalActionQueue}',
          subtitle:
              '${_analytics.pendingReportsCount} new · ${_analytics.pendingResolutionProofsCount} clear',
          icon: Icons.pending_actions_rounded,
          iconBg: const Color(0xFFFFF1E6),
          iconColor: const Color(0xFFD97706),
          decoration: _analyticsCardDecoration(),
        ),
      ),
      _AnalyticsOverviewKpiCard(
        title: 'Cleared Rate',
        value: resRate,
        subtitle:
            '${_analytics.scopedResolvedCount} cleared of ${_analytics.scopedActiveCount + _analytics.scopedResolvedCount}',
        icon: Icons.verified_outlined,
        iconBg: const Color(0xFFE8F7F0),
        iconColor: const Color(0xFF0F766E),
        decoration: _analyticsCardDecoration(),
      ),
      _AnalyticsOverviewKpiCard(
        title: 'Clearance Time',
        value: _analytics.formattedMedianClear,
        subtitle: 'Report to resolved',
        icon: Icons.timer_outlined,
        iconBg: const Color(0xFFEEF4F8),
        iconColor: _navy,
        decoration: _analyticsCardDecoration(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 340;
        if (!twoCols) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSevenDayVelocityCard() {
    final buckets = _analytics.last7DaysTrend;
    int maxVal = 1;
    for (final b in buckets) {
      maxVal = math.max(maxVal, math.max(b.reportedCount, b.resolvedCount));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _analyticsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Incident & Clearance Trend',
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tracks daily hazard intake against cleared incidents',
                      style: GoogleFonts.inter(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_analytics.sevenDayReportedTotal} in · ${_analytics.sevenDayResolvedTotal} out',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _LegendDotLabel(color: _navy, label: 'Reported'),
              SizedBox(width: 16),
              _LegendDotLabel(color: _teal, label: 'Resolved'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((bucket) {
                final double repFactor = bucket.reportedCount / maxVal;
                final double resFactor = bucket.resolvedCount / maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${bucket.reportedCount}/${bucket.resolvedCount}',
                          style: GoogleFonts.inter(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _TrendBarColumn(
                                  factor: repFactor,
                                  color: _navy,
                                ),
                                const SizedBox(width: 4),
                                _TrendBarColumn(
                                  factor: resFactor,
                                  color: _teal,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bucket.dayLabel,
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAndPipelineCard() {
    final categories = _analytics.topCategories;
    final int maxCategoryTotal =
        categories.isNotEmpty ? categories.first.totalCount : 1;

    final int pipelineTotal = math.max(1, _analytics.scopedReportsCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _analyticsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hazard Categories (${_selectedTimeframe.displayLabel})',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Identifies dominant road threats so routing & field response stay prioritized',
            style: GoogleFonts.inter(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hazard reports recorded in ${_selectedTimeframe.displayLabel.toLowerCase()}.',
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < categories.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _DetailedCategoryRow(
                stat: categories[i],
                maxTotal: maxCategoryTotal,
              ),
            ],
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE6EDF5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Report Outcome Pipeline',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _analytics.hasSignalDenominator
                    ? '${_analytics.signalApprovalPercent}% valid signal rate'
                    : 'No verified decisions yet',
                style: GoogleFonts.inter(
                  color: _teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PipelineCountChip(
                label: 'Active',
                count: _analytics.scopedActiveCount,
                total: pipelineTotal,
                bg: const Color(0xFFFEE2E2),
                fg: const Color(0xFFB91C1C),
              ),
              _PipelineCountChip(
                label: 'Pending',
                count: _analytics.scopedPendingCount,
                total: pipelineTotal,
                bg: const Color(0xFFFEF3C7),
                fg: const Color(0xFFB45309),
              ),
              _PipelineCountChip(
                label: 'Resolved',
                count: _analytics.scopedResolvedCount,
                total: pipelineTotal,
                bg: const Color(0xFFE8F7F0),
                fg: const Color(0xFF047857),
              ),
              _PipelineCountChip(
                label: 'Rejected',
                count: _analytics.scopedRejectedCount,
                total: pipelineTotal,
                bg: const Color(0xFFF1F5F9),
                fg: const Color(0xFF475569),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotsCard() {
    final hotspots = _analytics.topHotspots.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _analyticsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Hazard Hotspots by Area',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Streets & barangays ranked by active incidents and severe hazard density',
            style: GoogleFonts.inter(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (hotspots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No street-level hotspot addresses recorded in this timeframe yet.',
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < hotspots.length; i++) ...[
              if (i > 0) const Divider(height: 16, color: Color(0xFFE6EDF5)),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hotspots[i].activeCount > 0
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFEEF4F8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          color: hotspots[i].activeCount > 0
                              ? const Color(0xFFB91C1C)
                              : _navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotspots[i].areaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Primary threat: ${hotspots[i].topCategory}'
                          '${hotspots[i].highSeverityCount > 0 ? ' · ${hotspots[i].highSeverityCount} high risk' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: hotspots[i].activeCount > 0
                          ? const Color(0xFFFFF1E6)
                          : const Color(0xFFE8F7F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${hotspots[i].activeCount} active / ${hotspots[i].totalCount}',
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildAiAndResolutionQualityCard() {
    final avgConf = _analytics.averageAiConfidence;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _analyticsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Screening & Community Clearances',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Hazard Confidence',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        avgConf != null ? '$avgConf% avg' : '—',
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_analytics.highConfidenceCount} high · ${_analytics.mediumConfidenceCount} med · ${_analytics.lowConfidenceCount} low',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resolution Proofs',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_analytics.resolutionProofsApproved} approved',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0F766E),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_analytics.resolutionProofsPending} pending · ${_analytics.resolutionProofsRejected} rejected',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openReportManagement,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                'Open Report Management',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsOverviewKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final BoxDecoration decoration;

  const _AnalyticsOverviewKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F3A5F),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDotLabel extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDotLabel({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF5B6B7A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrendBarColumn extends StatelessWidget {
  final double factor;
  final Color color;

  const _TrendBarColumn({required this.factor, required this.color});

  @override
  Widget build(BuildContext context) {
    final double clamped = factor <= 0 ? 0.06 : factor.clamp(0.08, 1.0);
    return SizedBox(
      width: 10,
      height: 76,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: factor <= 0 ? color.withValues(alpha: 0.18) : color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailedCategoryRow extends StatelessWidget {
  final HazardCategoryStat stat;
  final int maxTotal;

  const _DetailedCategoryRow({
    required this.stat,
    required this.maxTotal,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        maxTotal > 0 ? (stat.totalCount / maxTotal).clamp(0.06, 1.0) : 0.0;
    final sharePct = (stat.share * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F3A5F),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${stat.activeCount} active · ${stat.resolvedCount} cleared · ${stat.totalCount} ($sharePct%)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B6B7A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE8EEF2),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: stat.highSeverityCount > 0
                          ? const Color(0xFF1F3A5F)
                          : const Color(0xFF61B5AB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PipelineCountChip extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color bg;
  final Color fg;

  const _PipelineCountChip({
    required this.label,
    required this.count,
    required this.total,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $count ($pct%)',
        style: GoogleFonts.inter(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminAboutSafeRouteScreen extends StatelessWidget {
  const AdminAboutSafeRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Platform Details',
      title: 'About SafeRoute',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _adminCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SafeRoute Admin Console v1.0.0',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2A41),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SafeRoute empowers communities and local administrators to monitor street hazards, verify AI-assisted commuter reports, and keep urban routes safe in real time.',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B6B7A),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0F4F8)),
            const SizedBox(height: 12),
            Text(
              'Security & Access Control',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2A41),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Administrator access is enforced through server-verified role policies and Supabase Row-Level Security.',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B6B7A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHelpSupportScreen extends StatelessWidget {
  const AdminHelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const faqs = [
      (
        'How do I review pending community reports?',
        'Open Report Management from the dashboard or your profile menu to search and inspect pending street hazard reports.'
      ),
      (
        'How are hazard categories and severity levels assigned?',
        'Reports are evaluated automatically during submission and queued according to urgency so high-risk hazards surface first.'
      ),
      (
        'Need technical assistance?',
        'Contact the SafeRoute Operations Desk at admin-support@saferoute.ph for role provisioning or incident escalation.'
      ),
    ];

    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Admin Assistance',
      title: 'Help & Support',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _adminCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < faqs.length; i++) ...[
              Text(
                faqs[i].$1,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E2A41),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                faqs[i].$2,
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B6B7A),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (i < faqs.length - 1) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF0F4F8)),
                const SizedBox(height: 14),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
