import 'dart:async';
import 'package:flutter/material.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../map_screen.dart';
import '../navigation/app_navigation.dart';
import '../services/alert_service.dart';
import '../services/hazard_report_service.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgWarm = Color(0xFFFAF8F5);
const Color _timeBlue = Color(0xFF5B82A6);
const Color _hazardRed = Color(0xFFE53935);
const Color _hazardBg = Color(0xFFFFF5F5);
const Color _hazardIconBg = Color(0xFFFFE5E5);
const Color _communityGreen = Color(0xFF2E7D32);
const Color _communityBg = Color(0xFFF3FAF6);
const Color _communityIconBg = Color(0xFFDDF3E7);
const Color _systemBlue = Color(0xFF1976D2);
const Color _systemBg = Color(0xFFF0F7FE);
const Color _systemIconBg = Color(0xFFD9ECFD);

class AlertsScreen extends StatefulWidget {
  final AlertService? alertService;
  final HazardReportService? hazardReportService;

  const AlertsScreen({
    super.key,
    this.alertService,
    this.hazardReportService,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();
  late final AlertService _alertService;
  StreamSubscription<HazardReportData>? _reportSubscription;

  int _selectedFilterIndex = 0;
  bool _isLoading = true;
  List<AlertItem> _alerts = <AlertItem>[];

  @override
  void initState() {
    super.initState();
    _alertService = widget.alertService ?? AlertService();
    _reportSubscription =
        HazardReportService.reportStream.listen(_onNewReportSubmitted);
    _loadAlerts();
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    final items = await _alertService.fetchAlerts(limit: 50);
    if (!mounted) return;
    setState(() {
      _alerts = items;
      _isLoading = false;
    });
  }

  void _onNewReportSubmitted(HazardReportData report) {
    if (!mounted) return;
    _loadAlerts();
  }

  List<AlertItem> get _hazardAlerts =>
      _alerts.where((a) => a.type == AlertType.hazard).toList();

  List<AlertItem> get _communityAlerts =>
      _alerts.where((a) => a.type == AlertType.community).toList();

  List<AlertItem> get _systemAlerts =>
      _alerts.where((a) => a.type == AlertType.system).toList();

  List<AlertItem> get _filteredAlerts {
    switch (_selectedFilterIndex) {
      case 1:
        return _hazardAlerts;
      case 2:
        return _communityAlerts;
      case 3:
        return _systemAlerts;
      case 0:
      default:
        return _alerts;
    }
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  void _syncUnreadNotifier() {
    AlertService.unreadCountNotifier.value = _unreadCount;
  }

  Future<void> _handleAlertTap(AlertItem alert) async {
    if (!alert.isRead) {
      setState(() {
        _alerts = _alerts
            .map((a) => a.id == alert.id ? a.copyWith(isRead: true) : a)
            .toList();
      });
      _syncUnreadNotifier();
      await _alertService.markAsRead(alert.id);
    }

    if (!mounted) return;

    if (alert.location != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            focusHazardLocation: alert.location,
            focusedReportId: alert.reportId,
            hazardReportService: widget.hazardReportService,
          ),
        ),
      );
      if (mounted) {
        _loadAlerts();
      }
      return;
    }

    _showSystemAlertDetailsSheet(alert);
  }

  Future<void> _handleMarkAllAsRead() async {
    final unreadIds =
        _alerts.where((a) => !a.isRead).map((a) => a.id).toList();
    if (unreadIds.isEmpty) return;

    setState(() {
      _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    });
    _syncUnreadNotifier();
    await _alertService.markAllAsRead(unreadIds);
  }

  Future<void> _handleDismissAlert(AlertItem alert, int originalIndex) async {
    setState(() {
      _alerts.removeWhere((a) => a.id == alert.id);
    });
    _syncUnreadNotifier();
    await _alertService.dismissAlert(alert.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dismissed "${alert.title}"',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF93C5FD),
          onPressed: () async {
            await _alertService.restoreDismissedAlert(alert.id);
            if (!mounted) return;
            setState(() {
              final insertIdx = originalIndex.clamp(0, _alerts.length);
              _alerts.insert(insertIdx, alert.copyWith(isRead: true));
            });
            _syncUnreadNotifier();
          },
        ),
      ),
    );
  }

  void _showSystemAlertDetailsSheet(AlertItem alert) {
    final style = _styleForAlertType(alert.type);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.overlineText,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: style.overlineColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            HazardReportService.formatRelativeTime(
                              alert.createdAt,
                            ),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: _secondaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      style.metaIcon,
                      size: 15,
                      color: const Color(0xFF5A6B82),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      alert.locationLabel,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF384E6D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ({
    Color cardBgColor,
    Color iconBgColor,
    IconData icon,
    Color iconColor,
    String overlineText,
    Color overlineColor,
    IconData metaIcon,
  }) _styleForAlertType(AlertType type) {
    switch (type) {
      case AlertType.hazard:
        return (
          cardBgColor: _hazardBg,
          iconBgColor: _hazardIconBg,
          icon: Icons.warning_amber_rounded,
          iconColor: _hazardRed,
          overlineText: 'HAZARD ALERT',
          overlineColor: _hazardRed,
          metaIcon: Icons.location_on_outlined,
        );
      case AlertType.community:
        return (
          cardBgColor: _communityBg,
          iconBgColor: _communityIconBg,
          icon: Icons.groups_rounded,
          iconColor: _communityGreen,
          overlineText: 'COMMUNITY UPDATE',
          overlineColor: _communityGreen,
          metaIcon: Icons.location_on_outlined,
        );
      case AlertType.system:
        return (
          cardBgColor: _systemBg,
          iconBgColor: _systemIconBg,
          icon: Icons.settings_rounded,
          iconColor: _systemBlue,
          overlineText: 'SYSTEM UPDATE',
          overlineColor: _systemBlue,
          metaIcon: Icons.access_time_rounded,
        );
    }
  }

  Future<bool> _showLogoutDialog() async {
    final nav = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _secondaryGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext, true);
              await _authService.signOut();
              if (mounted) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Log out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hazardRed,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlerts;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          return;
        }
        await _showLogoutDialog();
      },
      child: Scaffold(
        backgroundColor: _bgWarm,
        body: RefreshIndicator(
          color: _primaryNavy,
          onRefresh: _loadAlerts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Wave Header with Logo
                const CustomWavyHeader(),

                // Main Scrollable Content pulled up into the wave curve
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overline + Mark all read action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NOTIFICATIONS',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _secondaryGrey,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (_unreadCount > 0)
                              GestureDetector(
                                onTap: _handleMarkAllAsRead,
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _systemBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Main Title
                        const Text(
                          'Stay updated,\nstay safer.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _primaryNavy,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        const Text(
                          'Get the latest alerts, community reports, and important updates in your area.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _secondaryGrey,
                            height: 1.35,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Filter Chips Row
                        _buildFilterChipsRow(),

                        const SizedBox(height: 24),

                        if (_isLoading && filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _primaryNavy,
                                ),
                              ),
                            ),
                          )
                        else if (filtered.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 32,
                                  color: _secondaryGrey,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No alerts in this category',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryNavy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'New hazard reports and updates will appear here automatically.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: _secondaryGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          for (int i = 0; i < filtered.length; i++) ...[
                            Builder(
                              builder: (context) {
                                final alert = filtered[i];
                                final style = _styleForAlertType(alert.type);
                                final originalIndex = _alerts.indexOf(alert);
                                return Dismissible(
                                  key: ValueKey('alert_card_${alert.id}'),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => _handleDismissAlert(
                                    alert,
                                    originalIndex < 0 ? 0 : originalIndex,
                                  ),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: _hazardRed.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  child: _buildAlertCard(
                                    cardBgColor: style.cardBgColor,
                                    iconBgColor: style.iconBgColor,
                                    icon: style.icon,
                                    iconColor: style.iconColor,
                                    overlineText: style.overlineText,
                                    overlineColor: style.overlineColor,
                                    title: alert.title,
                                    body: alert.body,
                                    metaIcon: style.metaIcon,
                                    metaText: alert.locationLabel,
                                    timeElapsed:
                                        HazardReportService.formatRelativeTime(
                                      alert.createdAt,
                                    ),
                                    isUnread: !alert.isRead,
                                    onTap: () => _handleAlertTap(alert),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeRouteBottomNav(
          currentIndex: 2,
          onTap: (index) =>
              AppNavigation.navigateTo(context, index, currentIndex: 2),
        ),
      ),
    );
  }

  /// Horizontally scrollable row of custom filter chips with live DB counts
  Widget _buildFilterChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            index: 0,
            label: 'All',
            icon: Icons.notifications_rounded,
            defaultIconColor: _secondaryGrey,
            badgeCount: '${_alerts.length}',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 1,
            label: 'Hazard',
            icon: Icons.warning_amber_rounded,
            defaultIconColor: _hazardRed,
            badgeCount: '${_hazardAlerts.length}',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 2,
            label: 'Community',
            icon: Icons.groups_rounded,
            defaultIconColor: _communityGreen,
            badgeCount: '${_communityAlerts.length}',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 3,
            label: 'System',
            icon: Icons.settings_rounded,
            defaultIconColor: _systemBlue,
            badgeCount: '${_systemAlerts.length}',
          ),
        ],
      ),
    );
  }

  /// Reusable Filter Chip widget
  Widget _buildFilterChip({
    required int index,
    required String label,
    required IconData icon,
    required Color defaultIconColor,
    required String badgeCount,
  }) {
    final isSelected = _selectedFilterIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryNavy : const Color(0xFFE5E9EE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : defaultIconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF233253),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF33588A)
                    : const Color(0xFF6B8BB4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Alert Card matching target Figma layout
  Widget _buildAlertCard({
    required Color cardBgColor,
    required Color iconBgColor,
    required IconData icon,
    required Color iconColor,
    required String overlineText,
    required Color overlineColor,
    required String title,
    required String body,
    required IconData metaIcon,
    required String metaText,
    required String timeElapsed,
    bool isUnread = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: isUnread
              ? Border.all(
                  color: overlineColor.withValues(alpha: 0.28),
                  width: 1.2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left square icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top overline & time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnread) ...[
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  color: overlineColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: Text(
                                overlineText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: overlineColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeElapsed,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _timeBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Main Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Body text
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF5A6B82),
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Location/meta row
                  Row(
                    children: [
                      Icon(
                        metaIcon,
                        size: 13,
                        color: const Color(0xFF5A6B82),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF384E6D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right arrow
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Color(0xFF6B8BB4),
            ),
          ],
        ),
      ),
    );
  }
}
