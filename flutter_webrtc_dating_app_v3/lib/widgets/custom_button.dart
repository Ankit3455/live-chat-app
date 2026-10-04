import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

enum ButtonType { primary, outline, text }
enum ButtonSize { small, medium, large }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isSuccess;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final List<Color>? gradientColors;
  final double? width;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isSuccess = false,
    this.leftIcon,
    this.rightIcon,
    this.gradientColors,
    this.width,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case ButtonSize.small:
        return 48; // minimum touch target
      case ButtonSize.medium:
        return 52;
      case ButtonSize.large:
        return 60;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 18;
      case ButtonSize.medium:
        return 22;
      case ButtonSize.large:
        return 26;
    }
  }

  List<Color> get _gradientColors {
    return widget.gradientColors ?? AppColors.primaryGradient.colors;
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  void _onTapDown(TapDownDetails details) {
    if (_isDisabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    if (_isDisabled) return;
    HapticFeedback.mediumImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Semantics(
        button: true,
        enabled: !_isDisabled,
        // The spinner replaces the text while loading.
        label: widget.isLoading ? '${widget.text}, loading' : null,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: _onTap,
          child: _buildButton(),
        ),
      ),
    );
  }

  Widget _buildButton() {
    switch (widget.type) {
      case ButtonType.primary:
        return _buildPrimaryButton();
      case ButtonType.outline:
        return _buildOutlineButton();
      case ButtonType.text:
        return _buildTextButton();
    }
  }

  BorderRadius get _radius => BorderRadius.circular(_height / 2);

  Widget _buildPrimaryButton() {
    return Container(
      width: widget.width ?? double.infinity,
      constraints: BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: _isDisabled ? AppColors.surface2 : null,
        gradient: _isDisabled
            ? null
            : LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: _radius,
        boxShadow: _isDisabled
            ? const []
            : [
                BoxShadow(
                  color: AppColors.brandPink.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Center(
        child: _buildContent(
          _isDisabled && !widget.isLoading ? AppColors.textSubtle : Colors.white,
        ),
      ),
    );
  }

  Widget _buildOutlineButton() {
    return Container(
      width: widget.width ?? double.infinity,
      constraints: BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: _radius,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Center(
        child: _buildContent(
          _isDisabled ? AppColors.textSubtle : Colors.white,
        ),
      ),
    );
  }

  Widget _buildTextButton() {
    return Container(
      width: widget.width,
      constraints: BoxConstraints(minHeight: _height < 48 ? 48 : _height),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: _buildContent(
          _isDisabled ? AppColors.textSubtle : AppColors.brandPurpleLight,
        ),
      ),
    );
  }

  Widget _buildContent(Color color) {
    if (widget.isLoading) {
      return SizedBox(
        height: _iconSize,
        width: _iconSize,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2.5,
        ),
      );
    }

    if (widget.isSuccess) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: color, size: _iconSize),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: _fontSize,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leftIcon != null) ...[
          Icon(widget.leftIcon, color: color, size: _iconSize),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.15,
            ),
          ),
        ),
        if (widget.rightIcon != null) ...[
          const SizedBox(width: 10),
          Icon(widget.rightIcon, color: color, size: _iconSize),
        ],
      ],
    );
  }
}