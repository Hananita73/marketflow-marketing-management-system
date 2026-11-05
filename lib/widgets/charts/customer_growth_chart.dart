import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/theme.dart';

class CustomerGrowthData {
  final String month;
  final int customers;
  final int newCustomers;

  const CustomerGrowthData({
    required this.month,
    required this.customers,
    required this.newCustomers,
  });
}

class CustomerGrowthChart extends StatelessWidget {
  final List<CustomerGrowthData> data;
  final double height;

  const CustomerGrowthChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: AppColors.primary, label: 'Total Customers', textColor: textSec),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.info, label: 'New Customers', textColor: textSec),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            final groupWidth = chartWidth / data.length;
            final barWidth   = (groupWidth * 0.5) / 2;

            double maxVal = 0;
            for (final d in data) {
              maxVal = [maxVal, d.customers.toDouble(), d.newCustomers.toDouble()]
                  .reduce((a, b) => a > b ? a : b);
            }
            maxVal *= 1.15;

            return SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(data.length, (i) {
                  final d = data[i];
                  return Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(
                          value: d.customers.toDouble(),
                          maxVal: maxVal,
                          color: AppColors.primary,
                          width: barWidth,
                          displayValue: '${d.customers}',
                        ),
                        const SizedBox(width: 3),
                        _Bar(
                          value: d.newCustomers.toDouble(),
                          maxVal: maxVal,
                          color: AppColors.info,
                          width: barWidth,
                          displayValue: '${d.newCustomers}',
                        ),
                      ],
                    ),
                  );
                }),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: data
              .map((d) => Text(
                    d.month,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxVal;
  final Color color;
  final double width;
  final String displayValue;

  const _Bar({
    required this.value,
    required this.maxVal,
    required this.color,
    required this.width,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxVal == 0 ? 0.0 : (value / maxVal).clamp(0.02, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          displayValue,
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          width: width,
          height: 140 * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.6), color],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor, fontSize: 12)),
      ],
    );
  }
}
