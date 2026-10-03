import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        return 42;
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
    return widget.gradientColors ??
        [const Color(0xFF9333EA), const Color(0xFFEC4899)];
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
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        child: _buildButton(),
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

  Widget _buildPrimaryButton() {
    return Container(
      width: widget.width ?? double.infinity,
      height: _height,
      decoration: BoxDecoration(
        gradient: _isDisabled
            ? LinearGradient(
          colors: [Colors.grey.shade400, Colors.grey.shade500],
        )
            : LinearGradient(
          colors: _gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isDisabled
            ? []
            : [
          BoxShadow(
            color: _gradientColors.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(child: _buildContent(Colors.white)),
    );
  }

  Widget _buildOutlineButton() {
    return Container(
      width: widget.width ?? double.infinity,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDisabled ? Colors.grey : _gradientColors.first,
          width: 2,
        ),
      ),
      child: Center(
        child: _buildContent(
          _isDisabled ? Colors.grey : _gradientColors.first,
        ),
      ),
    );
  }

  Widget _buildTextButton() {
    return SizedBox(
      width: widget.width,
      height: _height,
      child: Center(
        child: _buildContent(
          _isDisabled ? Colors.grey : _gradientColors.first,
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
          Text(
            widget.text,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              color: color,
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
        Text(
          widget.text,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
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