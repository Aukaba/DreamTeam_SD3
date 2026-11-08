import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _lightBlue = Color(0xFFEFF5FB);
const Color _badgeBlue = Color(0xFFEAF2FB);
const Color _accentBlue = Color(0xFF7098C2);
const Color _alertRed = Color(0xFFE53935);
const Color _lightRed = Color(0xFFFFEBEE);

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<({String title, String subtitle, IconData icon})> _guides = [
    (
      title: '1. Reporting a Community Hazard',
      subtitle:
          'Tap Report Hazard on Home or Map, take or upload a photo, and Gemini AI will automatically verify the hazard category and severity level.',
      icon: Icons.camera_alt_outlined,
    ),
    (
      title: '2. Planning & Saving Safe Routes',
      subtitle:
          'On the Map screen, choose your origin and destination to compare Safe Route options and tap Save Route for quick access on your profile.',
      icon: Icons.alt_route_rounded,
    ),
    (
      title: '3. Earning Safety Points & Leveling Up',
      subtitle:
          'Every verified report awards points based on severity (Low = 1 pt, Medium = 2 pts, High = 3 pts). Level 1 requires 20 points, and each level requires 25% more.',
      icon: Icons.emoji_events_outlined,
    ),
  ];

  static const List<({String question, String answer, String tag})> _faqs = [
    (
      question:
          'Why are Hazard Category and Security Level locked when reporting?',
      answer:
          'To ensure consistent and trustworthy community safety alerts, SafeRoute uses Gemini AI to evaluate the uploaded photo and assign the appropriate category and severity level automatically.',
      tag: 'Hazard Reporting',
    ),
    (
      question: 'How does the SafeRoute Leaderboard calculate points?',
      answer:
          'Each submitted hazard counts as 1 report. Low severity awards 1 point, Medium awards 2 points, and High awards 3 points. At Level 1 you need 20 points to reach Level 2, and each subsequent level requires 1/4 (25%) more points than the previous level.',
      tag: 'Leaderboard & Levels',
    ),
    (
      question:
          'Where can I view or delete my submitted reports and saved routes?',
      answer:
          'Open the Profile tab and under COMMUNITY tap My Reports to inspect or delete past hazard reports, or tap Saved Routes to rename, delete, or launch navigation for your saved routes.',
      tag: 'Profile & Community',
    ),
    (
      question: 'I did not receive my password reset or verification email.',
      answer:
          'Check your Spam or Promotions folder, ensure the email address matches your registered SafeRoute account, and wait 60 seconds before requesting another link.',
      tag: 'Account & Security',
    ),
    (
      question: 'How do I sign out of other devices if I lost my phone?',
      answer:
          'Go to Profile > Security and under Session & Device Access tap Sign Out of Other Devices or Sign Out Everywhere to revoke active tokens immediately.',
      tag: 'Account & Security',
    ),
  ];

  static const List<({String name, String number, String subtitle})>
      _emergencyContacts = [
    (
      name: 'National Emergency Hotline',
      number: '911',
      subtitle: 'Police, Fire, and Medical Emergencies (24/7)',
    ),
    (
      name: 'Cebu City Disaster Risk Reduction (CCDRRMO)',
      number: '166',
      subtitle: 'Flood, landslide, and urban hazard response',
    ),
    (
      name: 'Philippine Red Cross Hotline',
      number: '143',
      subtitle: 'Emergency medical & rescue assistance',
    ),
  ];

  Future<void> _copyToClipboard(
    BuildContext context,
    String text,
    String label,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$label copied: $text'),
            backgroundColor: _primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to copy $label. Please copy it manually: $text',
            ),
            backgroundColor: _alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBeige,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _primaryNavy,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Emergency Hotlines Quick Reference
            _buildSectionLabel('EMERGENCY HOTLINES'),
            _buildCardGroup(
              children: [
                for (var i = 0; i < _emergencyContacts.length; i++) ...[
                  _buildEmergencyTile(context, _emergencyContacts[i]),
                  if (i < _emergencyContacts.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFF0F2F6)),
                    ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 2. Quick Start Guides
            _buildSectionLabel('SAFEROUTE QUICK GUIDES'),
            _buildCardGroup(
              children: [
                for (var i = 0; i < _guides.length; i++) ...[
                  _buildGuideTile(_guides[i]),
                  if (i < _guides.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFF0F2F6)),
                    ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 3. Frequently Asked Questions
            _buildSectionLabel('FREQUENTLY ASKED QUESTIONS'),
            _buildCardGroup(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        10,
                        0,
                        10,
                        12,
                      ),
                      iconColor: _primaryNavy,
                      collapsedIconColor: _secondaryGrey,
                      title: Text(
                        _faqs[i].question,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _faqs[i].tag,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _accentBlue,
                          ),
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _faqs[i].answer,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              height: 1.5,
                              color: _secondaryGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _faqs.length - 1)
                    const Divider(height: 1, color: Color(0xFFF0F2F6)),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 4. Direct Contact Support Card
            _buildSectionLabel('CONTACT SUPPORT'),
            _buildCardGroup(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: _badgeBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: _primaryNavy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SafeRoute Support Desk',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _primaryNavy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'support@saferoute.ph • Mon–Sun, 8:00 AM – 8:00 PM',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: _secondaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('copy_support_email_button'),
                      onTap: () => _copyToClipboard(
                        context,
                        'support@saferoute.ph',
                        'Support Email',
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _lightBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Copy Email',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _primaryNavy,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: _primaryNavy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTile(
    BuildContext context,
    ({String name, String number, String subtitle}) item,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _lightRed,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.phone_in_talk_rounded,
            color: _alertRed,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
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
        InkWell(
          onTap: () => _copyToClipboard(context, item.number, item.name),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _lightRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.number,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _alertRed,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 13, color: _alertRed),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideTile(
    ({String title, String subtitle, IconData icon}) guide,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _lightBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(guide.icon, color: _primaryNavy, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                guide.subtitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  height: 1.45,
                  color: _secondaryGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: _secondaryGrey,
        ),
      ),
    );
  }

  Widget _buildCardGroup({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
