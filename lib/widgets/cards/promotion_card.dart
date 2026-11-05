import 'package:flutter/material.dart';

class PromotionCard extends StatelessWidget {
  final String title;
  final String description;
  final String discount;
  final String status;
  final String endDate;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PromotionCard({
    super.key,
    required this.title,
    required this.description,
    required this.discount,
    required this.status,
    required this.endDate,
    required this.icon,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  Color get _statusColor {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF40916C);
      case 'expired':
        return const Color(0xFFE63946);
      case 'scheduled':
        return const Color(0xFFF4A261);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2D6A4F).withValues(alpha: 0.15),
                          const Color(0xFF52B788).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: const Color(0xFF2D6A4F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      discount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE8F5E9)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        status.toLowerCase() == 'active'
                            ? Icons.check_circle_rounded
                            : status.toLowerCase() == 'expired'
                                ? Icons.cancel_rounded
                                : Icons.schedule_rounded,
                        size: 14,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: Color(0xFF8A99AA)),
                      const SizedBox(width: 4),
                      Text(
                        endDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A99AA),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (onEdit != null)
                        _ActionIcon(
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF0F4C75),
                          onTap: onEdit!,
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        _ActionIcon(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFC62828),
                          onTap: onDelete!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
