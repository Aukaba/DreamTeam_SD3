import 'package:flutter/material.dart';
import '../services/safe_route_service.dart';

/// Opens a scrollable bottom sheet listing all turn-by-turn maneuvers.
Future<void> showRouteStepsBottomSheet(
  BuildContext context, {
  required RouteCandidate route,
  required int currentStepIndex,
  ValueChanged<RouteStep>? onStepTapped,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.78,
          ),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Turn-by-Turn Directions',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF263354),
                            ),
                          ),
                          Text(
                            '${route.distanceAndTimeLabel} · ${route.steps.length} steps',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF8A94A6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8A94A6),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: route.steps.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final step = route.steps[idx];
                    final isCurrent = idx == currentStepIndex;
                    final isCompleted = idx < currentStepIndex;

                    return Material(
                      color: isCurrent
                          ? const Color(0xFFEBF3FE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          onStepTapped?.call(step);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFF2563EB)
                                      : (isCompleted
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFF1F5F9)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_rounded
                                      : step.maneuverType.icon,
                                  size: 18,
                                  color: isCurrent
                                      ? Colors.white
                                      : (isCompleted
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF263354)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.instruction,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: isCurrent
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isCompleted
                                            ? const Color(0xFF8A94A6)
                                            : const Color(0xFF263354),
                                      ),
                                    ),
                                    if (step.streetName.isNotEmpty)
                                      Text(
                                        step.streetName,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: Color(0xFF8A94A6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (step.distanceMeters > 0)
                                Text(
                                  step.formattedDistance,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Overlay shown on [MapScreen] while previewing/comparing safe route candidates
/// before starting active turn-by-turn navigation.
class RoutePreviewOverlay extends StatelessWidget {
  final PlannedRouteResult routeResult;
  final bool isRecalculating;
  final bool isRouteSaved;
  final bool showTraffic;
  final VoidCallback? onToggleTraffic;
  final VoidCallback onExitRoute;
  final VoidCallback onTapOrigin;
  final VoidCallback onTapDestination;
  final VoidCallback onSwapEndpoints;
  final ValueChanged<RouteTravelMode> onTravelModeChanged;
  final ValueChanged<bool> onAvoidHazardsChanged;
  final ValueChanged<RouteCandidate> onCandidateSelected;
  final VoidCallback onSaveRoute;
  final VoidCallback onStartTurnByTurn;
  final ValueChanged<RouteStep> onFocusStep;

  const RoutePreviewOverlay({
    super.key,
    required this.routeResult,
    required this.isRecalculating,
    required this.isRouteSaved,
    this.showTraffic = false,
    this.onToggleTraffic,
    required this.onExitRoute,
    required this.onTapOrigin,
    required this.onTapDestination,
    required this.onSwapEndpoints,
    required this.onTravelModeChanged,
    required this.onAvoidHazardsChanged,
    required this.onCandidateSelected,
    required this.onSaveRoute,
    required this.onStartTurnByTurn,
    required this.onFocusStep,
  });

  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _safeGreen = Color(0xFF15803D);
  static const Color _safeGreenBg = Color(0xFFDCFCE7);
  static const Color _warnAmber = Color(0xFFB45309);
  static const Color _warnAmberBg = Color(0xFFFEF3C7);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final primary = routeResult.primaryRoute;
    final onRouteCount = primary.hazardsOnRoute.length;
    final avoidedCount = routeResult.hazardsAvoided;

    Color bannerBg = _safeGreenBg;
    Color bannerFg = _safeGreen;
    IconData bannerIcon = Icons.verified_user_rounded;
    String bannerText = avoidedCount > 0
        ? 'Hazard-free road prioritized · Avoided $avoidedCount hazard${avoidedCount == 1 ? '' : 's'}'
        : 'Clear road prioritized · 0 active hazards on route';

    if (onRouteCount > 0) {
      if (primary.riskLevel == RouteRiskLevel.high) {
        bannerBg = _dangerRedBg;
        bannerFg = _dangerRed;
      } else {
        bannerBg = _warnAmberBg;
        bannerFg = _warnAmber;
      }
      bannerIcon = Icons.warning_amber_rounded;
      bannerText = avoidedCount > 0
          ? 'Lowest-risk road selected (avoided $avoidedCount, $onRouteCount nearby)'
          : '$onRouteCount active hazard${onRouteCount == 1 ? '' : 's'} near route — stay alert';
    }

    return Stack(
      children: [
        // 1. Top Origin/Destination & Mode Controls Card
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: onExitRoute,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: _primaryNavy,
                          size: 22,
                        ),
                        tooltip: 'Back',
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildEndpointRow(
                              dotColor: _accentBlue,
                              text: routeResult.originLabel,
                              onTap: onTapOrigin,
                            ),
                            const SizedBox(height: 6),
                            _buildEndpointRow(
                              dotColor: _primaryNavy,
                              isFlag: true,
                              text: routeResult.destinationLabel,
                              onTap: onTapDestination,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onSwapEndpoints,
                        icon: const Icon(
                          Icons.swap_vert_rounded,
                          color: _primaryNavy,
                          size: 22,
                        ),
                        tooltip: 'Swap origin & destination',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final mode in RouteTravelMode.values) ...[
                          _buildModeChip(mode),
                          const SizedBox(width: 6),
                        ],
                        FilterChip(
                          selected: routeResult.avoidHazards,
                          onSelected: onAvoidHazardsChanged,
                          showCheckmark: false,
                          avatar: Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: routeResult.avoidHazards
                                ? Colors.white
                                : _primaryNavy,
                          ),
                          label: Text(
                            'Avoid Hazards',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: routeResult.avoidHazards
                                  ? Colors.white
                                  : _primaryNavy,
                            ),
                          ),
                          selectedColor: _safeGreen,
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (onToggleTraffic != null) ...[
                          const SizedBox(width: 6),
                          FilterChip(
                            key: const Key('route_preview_traffic_toggle_button'),
                            selected: showTraffic,
                            onSelected: (_) => onToggleTraffic?.call(),
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.traffic_rounded,
                              size: 15,
                              color: showTraffic ? Colors.white : _primaryNavy,
                            ),
                            label: Text(
                              'Traffic',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: showTraffic ? Colors.white : _primaryNavy,
                              ),
                            ),
                            selectedColor: _accentBlue,
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isRecalculating)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        color: _accentBlue,
                        backgroundColor: Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 2. Bottom Route Summary, Candidate Switcher, and Start Turn-by-Turn Button
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Safety Status Pill Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bannerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(bannerIcon, size: 17, color: bannerFg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bannerText,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: bannerFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Primary Route Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      primary.distanceAndTimeLabel,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: _primaryNavy,
                                      ),
                                    ),
                                  ),
                                  if (primary.trafficDelaySeconds > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary.trafficDelaySeconds >= 180
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        primary.trafficDelayLabel,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: primary.trafficDelaySeconds >= 180
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                primary.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: _secondaryGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showRouteStepsBottomSheet(
                            context,
                            route: primary,
                            currentStepIndex: 0,
                            onStepTapped: onFocusStep,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryNavy,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 16,
                          ),
                          label: Text(
                            '${primary.steps.length} Steps',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Candidate Route Comparison Chips (when alternatives exist)
                    if (routeResult.alternatives.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: routeResult.alternatives.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final cand = routeResult.alternatives[idx];
                            final selected = cand.id == primary.id;
                            final hCount = cand.hazardsOnRoute.length;
                            final tag = idx == 0 && routeResult.avoidHazards
                                ? 'Safest'
                                : 'Option ${idx + 1}';

                            final trafficPart = cand.trafficDelaySeconds > 0
                                ? ' · ${cand.trafficDelayLabel}'
                                : '';
                            return ChoiceChip(
                              selected: selected,
                              onSelected: (_) => onCandidateSelected(cand),
                              showCheckmark: false,
                              selectedColor: _primaryNavy,
                              backgroundColor: const Color(0xFFF4F6F9),
                              label: Text(
                                '$tag · ${cand.formattedDuration}$trafficPart (${hCount == 0 ? '0 hazards' : '$hCount hazard${hCount == 1 ? '' : 's'}'})',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : _primaryNavy,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Save + Start Turn-by-Turn Action Row
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isRouteSaved
                                ? _safeGreenBg
                                : const Color(0xFFF4F6F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            onPressed: onSaveRoute,
                            tooltip: isRouteSaved ? 'Route saved' : 'Save route',
                            icon: Icon(
                              isRouteSaved
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              color: isRouteSaved ? _safeGreen : _primaryNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: onStartTurnByTurn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentBlue,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.navigation_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Start Turn-by-Turn',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndpointRow({
    required Color dotColor,
    required String text,
    required VoidCallback onTap,
    bool isFlag = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isFlag ? Icons.flag_rounded : Icons.trip_origin_rounded,
              size: 14,
              color: dotColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(RouteTravelMode mode) {
    final selected = routeResult.travelMode == mode;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTravelModeChanged(mode),
      showCheckmark: false,
      avatar: Icon(
        mode.icon,
        size: 15,
        color: selected ? Colors.white : _primaryNavy,
      ),
      label: Text(
        mode.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _primaryNavy,
        ),
      ),
      selectedColor: _primaryNavy,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Active live Turn-by-Turn Navigation HUD rendered on [MapScreen].
class TurnByTurnNavigationHud extends StatelessWidget {
  final PlannedRouteResult routeResult;
  final int currentStepIndex;
  final double distanceToNextTurnMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final bool isFollowingUser;
  final bool isSimulating;
  final bool hasArrived;
  final bool isRerouting;
  final String? hazardWarningBanner;
  final VoidCallback onRecenter;
  final VoidCallback onToggleSimulation;
  final VoidCallback onPrevStep;
  final VoidCallback onNextStep;
  final VoidCallback onRequestSafeReroute;
  final VoidCallback onStopNavigation;
  final VoidCallback onReportHazard;
  final ValueChanged<RouteStep> onFocusStep;

  const TurnByTurnNavigationHud({
    super.key,
    required this.routeResult,
    required this.currentStepIndex,
    required this.distanceToNextTurnMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.isFollowingUser,
    required this.isSimulating,
    required this.hasArrived,
    required this.isRerouting,
    this.hazardWarningBanner,
    required this.onRecenter,
    required this.onToggleSimulation,
    required this.onPrevStep,
    required this.onNextStep,
    required this.onRequestSafeReroute,
    required this.onStopNavigation,
    required this.onReportHazard,
    required this.onFocusStep,
  });

  static const Color _hudNavy = Color(0xFF1E293B);
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _accentBlue = Color(0xFF2563EB);

  String _formatEtaClock(BuildContext context, int secondsFromNow) {
    final arrival = DateTime.now().add(Duration(seconds: secondsFromNow));
    return TimeOfDay.fromDateTime(arrival).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final route = routeResult.primaryRoute;
    final steps = route.steps;
    final safeIdx = steps.isEmpty
        ? 0
        : currentStepIndex.clamp(0, steps.length - 1);
    final currentStep = steps.isNotEmpty
        ? steps[safeIdx]
        : RouteStep(
            index: 0,
            instruction: 'Head toward ${routeResult.destinationLabel}',
            streetName: routeResult.destinationLabel,
            distanceMeters: remainingDistanceMeters,
            durationSeconds: remainingDurationSeconds,
            maneuverType: ManeuverType.straight,
            location: routeResult.destination,
            startPolylineIndex: 0,
            endPolylineIndex: 0,
          );
    final RouteStep? nextStep =
        (safeIdx + 1 < steps.length) ? steps[safeIdx + 1] : null;

    return Stack(
      children: [
        // 1. TOP TURN-BY-TURN MANEUVER BANNER
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _hudNavy,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: hasArrived
                                    ? const Color(0xFF16A34A)
                                    : _accentBlue,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                hasArrived
                                    ? Icons.check_circle_rounded
                                    : currentStep.maneuverType.icon,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        hasArrived
                                            ? 'Arrived'
                                            : 'In ${SafeRouteService.formatDistance(distanceToNextTurnMeters)}',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF93C5FD),
                                        ),
                                      ),
                                      if (isRerouting) ...[
                                        const SizedBox(width: 8),
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          'Rerouting...',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasArrived
                                        ? 'You have arrived at ${routeResult.destinationLabel}'
                                        : currentStep.instruction,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // "Then" Next Maneuver Strip
                      if (!hasArrived && nextStep != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Then',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                nextStep.maneuverType.icon,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  nextStep.instruction,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
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
                ),

                // Live Hazard Alert Banner (if an active hazard is reported ahead)
                if (hazardWarningBanner != null && !hasArrived)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hazardWarningBanner!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onRequestSafeReroute,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Reroute',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 2. FLOATING RIGHT NAVIGATION CONTROLS (Recenter, Simulate, Report Hazard)
        Positioned(
          right: 16,
          bottom: 158,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Simulate / Demo Walk Pill
              Material(
                color: isSimulating ? _accentBlue : Colors.white,
                borderRadius: BorderRadius.circular(22),
                elevation: 4,
                child: InkWell(
                  onTap: onToggleSimulation,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSimulating
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                          color: isSimulating ? Colors.white : _primaryNavy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSimulating ? 'Pause Demo' : 'Simulate',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isSimulating ? Colors.white : _primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'nav_report_hazard_fab',
                backgroundColor: _primaryNavy,
                foregroundColor: Colors.white,
                tooltip: 'Report hazard on road',
                onPressed: onReportHazard,
                child: const Icon(Icons.add_alert_rounded, size: 19),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'nav_recenter_fab',
                backgroundColor: Colors.white,
                foregroundColor: isFollowingUser ? _accentBlue : _primaryNavy,
                tooltip: 'Follow my position',
                onPressed: onRecenter,
                child: Icon(
                  isFollowingUser
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // 3. BOTTOM TURN-BY-TURN METRICS & STEP CONTROLS BAR
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      hasArrived
                                          ? 'Arrived safely!'
                                          : SafeRouteService.formatDuration(
                                              remainingDurationSeconds,
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: hasArrived
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  if (!hasArrived) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '(${SafeRouteService.formatDistance(remainingDistanceMeters)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _primaryNavy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasArrived
                                    ? routeResult.destinationLabel
                                    : 'ETA ${_formatEtaClock(context, remainingDurationSeconds)} · Step ${safeIdx + 1} of ${steps.isEmpty ? 1 : steps.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Step Prev / All Steps / Next Controls
                        IconButton(
                          onPressed: safeIdx > 0 ? onPrevStep : null,
                          tooltip: 'Previous step',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          onPressed: () => showRouteStepsBottomSheet(
                            context,
                            route: route,
                            currentStepIndex: safeIdx,
                            onStepTapped: onFocusStep,
                          ),
                          tooltip: 'All steps',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: _primaryNavy,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              safeIdx + 1 < steps.length ? onNextStep : null,
                          tooltip: 'Next step',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                        const SizedBox(width: 6),

                        // End / Finish Navigation Button
                        ElevatedButton(
                          onPressed: onStopNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasArrived
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            hasArrived ? 'Done' : 'End',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
