import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String managerName;
  final int totalCalls;
  final double totalTurnover;
  final int clientMeetings;
  final int targetCalls;
  final int targetMeetings;
  final int targetUv;
  final VoidCallback? onTap;
  final bool isLead;
  final bool isManager;
  final bool isTeam;
  final Widget? trailing;
  final bool hideStats;
  final bool showMemberFormat;

  const InfoCard({
    super.key,
    required this.managerName,
    required this.totalCalls,
    required this.totalTurnover,
    required this.clientMeetings,
    this.targetCalls = 0,
    this.targetMeetings = 0,
    this.targetUv = 0,
    this.onTap,
    this.isLead = false,
    this.isManager = false,
    this.isTeam = false,
    this.hideStats = false,
    this.showMemberFormat = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      managerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isLead)
                    _roleBadge('LS', Icons.star, Colors.amber.shade400),
                  if (isManager)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _roleBadge('LDC', Icons.workspace_premium, Colors.cyanAccent),
                    ),
                  if (isTeam)
                    _roleBadge('IR', Icons.group, Colors.purple.shade300),
                  if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8.0), child: trailing!),
                ],
              ),
              if (!hideStats) ...[
                const SizedBox(height: 12),
                if (showMemberFormat)
                  _buildMemberStats()
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoTile(
                        "Calls",
                        targetCalls > 0 ? "$totalCalls/$targetCalls" : "$totalCalls",
                      ),
                      _infoTile(
                        "UVs",
                        _formatNumberWithTarget(totalTurnover, targetUv),
                        highlight: true,
                      ),
                      _infoTile(
                        "Plans",
                        targetMeetings > 0 ? "$clientMeetings/$targetMeetings" : "$clientMeetings",
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberStats() {
    final callsValue = targetCalls > 0 ? "$totalCalls/$targetCalls" : "$totalCalls";
    final plansValue = targetMeetings > 0 ? "$clientMeetings/$targetMeetings" : "$clientMeetings";
    final uvValue = _formatNumberWithTarget(totalTurnover, targetUv);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statRow("Total Calls", callsValue),
            ),
            Expanded(
              child: _statRow("UVs", uvValue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statRow("Plans", plansValue),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String title, String value, {bool highlight = false}) {
    return Flexible(
      fit: FlexFit.loose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.cyanAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumberWithTarget(double value, int target) {
    final String base;
    if (value.isNaN || value.isInfinite) {
      base = '0';
    } else if (value == value.roundToDouble()) {
      base = value.toInt().toString();
    } else {
      base = value.toStringAsFixed(2);
    }

    if (target > 0) {
      return '$base/$target';
    }
    return base;
  }
}
