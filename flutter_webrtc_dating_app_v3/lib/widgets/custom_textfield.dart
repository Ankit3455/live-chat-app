import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;     // ✅ Added support
  final bool enabled;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,            // ✅ Added
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.brandViolet)
            : null,
        suffixIcon: suffixIcon,        // ✅ Works now
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
