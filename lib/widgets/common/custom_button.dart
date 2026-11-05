import 'package:flutter/material.dart';
import '../../core/colors.dart';

enum ButtonVariant { primary, secondary, outlined, danger, ghost }
enum ButtonSize { small, medium, large }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;
  final bool fullWidth;
  final double? borderRadius;
  final Color? customColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.borderRadius,
    this.customColor,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Color get _primaryColor => widget.customColor ?? AppColors.primary;

  double get _height {
    switch (widget.size) {
      case ButtonSize.small:
        return 38;
      case ButtonSize.medium:
        return 50;
      case ButtonSize.large:
        return 58;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 13;
      case ButtonSize.medium:
        return 15;
      case ButtonSize.large:
        return 17;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 15;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 21;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 14);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 28);
    }
  }

  Color get _backgroundColor {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return _primaryColor;
      case ButtonVariant.secondary:
        return _primaryColor.withValues(alpha: 0.12);
      case ButtonVariant.outlined:
        return Colors.transparent;
      case ButtonVariant.danger:
        return AppColors.danger;
      case ButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Colors.white;
      case ButtonVariant.secondary:
        return _primaryColor;
      case ButtonVariant.outlined:
        return _primaryColor;
      case ButtonVariant.danger:
        return Colors.white;
      case ButtonVariant.ghost:
        return _primaryColor;
    }
  }

  Color get _disabledBgColor {
    switch (widget.variant) {
      case ButtonVariant.outlined:
      case ButtonVariant.ghost:
        return Colors.transparent;
      default:
        return AppColors.border;
    }
  }

  BorderSide get _borderSide {
    switch (widget.variant) {
      case ButtonVariant.outlined:
        return BorderSide(color: _primaryColor, width: 1.8);
      case ButtonVariant.danger:
        return BorderSide(
            color: AppColors.danger.withValues(alpha: 0.3), width: 1.5);
      case ButtonVariant.ghost:
        return BorderSide.none;
      default:
        return BorderSide.none;
    }
  }

  List<BoxShadow> get _shadow {
    if (widget.variant == ButtonVariant.primary &&
        widget.onPressed != null &&
        !widget.isLoading) {
      return [
        BoxShadow(
          color: _primaryColor.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];
    }
    if (widget.variant == ButtonVariant.danger &&
        widget.onPressed != null &&
        !widget.isLoading) {
      return [
        BoxShadow(
          color: AppColors.danger.withValues(alpha: 0.3),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];
    }
    return [];
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? 12.0;

    // ── Core decorated + animated container ───────────────────────────────
    // width is handled OUTSIDE this container so we never hand
    // double.infinity to AnimatedContainer when the parent is unbounded
    // (e.g. inside a Row inside a Dialog), which throws:
    //   "BoxConstraints forces an infinite width"
    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _height,
      // width is intentionally omitted here — controlled by the wrapper below
      decoration: BoxDecoration(
        color: _isDisabled && widget.variant != ButtonVariant.outlined
            ? _disabledBgColor
            : _backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: _borderSide == BorderSide.none
            ? null
            : Border.fromBorderSide(
                _isDisabled
                    ? _borderSide.copyWith(
                        color: _borderSide.color.withValues(alpha: 0.3))
                    : _borderSide,
              ),
        boxShadow: _isDisabled ? [] : _shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: _isDisabled ? null : widget.onPressed,
          splashColor: _foregroundColor.withValues(alpha: 0.12),
          highlightColor: _foregroundColor.withValues(alpha: 0.06),
          child: Padding(
            padding: _padding,
            child: Center(
              child: widget.isLoading ? _buildLoader() : _buildContent(),
            ),
          ),
        ),
      ),
    );

    // ── Width strategy ─────────────────────────────────────────────────────
    // fullWidth: use LayoutBuilder so we only stretch when the parent
    // provides a *finite* constraint.  If the parent is unbounded (Row in a
    // Dialog, etc.) we fall back to intrinsic width — no crash.
    Widget sized;
    if (widget.fullWidth) {
      sized = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedWidth) {
            // Parent gave us a real width → fill it
            return SizedBox(width: constraints.maxWidth, child: container);
          } else {
            // Unbounded parent (Row, unconstrained column) → intrinsic width
            return IntrinsicWidth(child: container);
          }
        },
      );
    } else {
      // Explicit compact / inline button → never stretch
      sized = IntrinsicWidth(child: container);
    }

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          if (!_isDisabled) _pressController.forward();
        },
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: sized,
      ),
    );
  }

  Widget _buildLoader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.variant == ButtonVariant.primary ||
                      widget.variant == ButtonVariant.danger
                  ? Colors.white
                  : _primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Please wait...',
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: _isDisabled ? const Color(0xFF90A4AE) : _foregroundColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final color = _isDisabled ? const Color(0xFF90A4AE) : _foregroundColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.prefixIcon != null) ...[
          Icon(widget.prefixIcon, size: _iconSize, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
        if (widget.suffixIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.suffixIcon, size: _iconSize, color: color),
        ],
      ],
    );
  }
}
