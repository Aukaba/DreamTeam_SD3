import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const coverageItems = [
      ('Cebu City Downtown & Santa Cruz', '96%', '14 active monitors'),
      ('Capitol Site & Fuente Osmeña', '94%', '11 active monitors'),
      ('Lahug & IT Park Corridor', '91%', '9 active monitors'),
      ('N. Bacalso & South Coastal', '88%', '14 active monitors'),
    ];

    return _buildAdminPageScaffold(
      context: context,
      subtitle: 'Coverage & Verification',
      title: 'Analytics Overview',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _adminCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitored Zones (92% Overall Coverage)',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E2A41),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final zone in coverageItems) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zone.$1,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1E2A41),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                zone.$3,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF738297),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            zone.$2,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1F3A5F),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminReportsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3A5F),
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
          ),
        ],
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
