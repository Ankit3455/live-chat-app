import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/astrology_utils.dart';

/// Standalone astrology questionnaire form
/// Converted from AstrologyQuestionnaireFragment.kt
class AstrologyQuestionnaireFragment extends StatefulWidget {
  const AstrologyQuestionnaireFragment({super.key});

  @override
  State<AstrologyQuestionnaireFragment> createState() =>
      _AstrologyQuestionnaireFragmentState();
}

class _AstrologyQuestionnaireFragmentState
    extends State<AstrologyQuestionnaireFragment> {
  final _formKey = GlobalKey<FormState>();
  final _timeController = TextEditingController();
  final _placeController = TextEditingController();
  final _luckyNumberController = TextEditingController();

  final List<String> _selectedSigns = [];
  String? _selectedElement;
  String _computedZodiac = '-';

  @override
  void dispose() {
    _timeController.dispose();
    _placeController.dispose();
    _luckyNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.purplePrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _timeController.text = picked.format(context);
    }
  }

  Future<void> _saveToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showError('Not signed in');
      return;
    }

    final updates = {
      'timeOfBirth': _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim(),
      'placeOfBirth': _placeController.text.trim().isEmpty
          ? null
          : _placeController.text.trim(),
      'preferredSigns': _selectedSigns,
      'preferredElement':
          _selectedElement?.isEmpty ?? true ? null : _selectedElement,
      'luckyNumber': int.tryParse(_luckyNumberController.text.trim()),
    };

    try {
      await FirebaseDatabase.instance
          .ref('users')
          .child(uid)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Astrology saved ✨'),
            backgroundColor: AppColors.connectColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Save failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.dangerRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              const Text(
                'Astrology Questionnaire',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Time of Birth
              TextField(
                controller: _timeController,
                readOnly: true,
                onTap: _pickTime,
                style: const TextStyle(color: AppColors.inputTextWhite),
                decoration: const InputDecoration(
                  labelText: 'Time of birth (HH:mm)',
                  suffixIcon: Icon(Icons.access_time),
                ),
              ),

              const SizedBox(height: 16),

              // Place of Birth
              TextField(
                controller: _placeController,
                style: const TextStyle(color: AppColors.inputTextWhite),
                decoration: const InputDecoration(
                  labelText: 'Place of birth',
                  suffixIcon: Icon(Icons.location_on),
                ),
              ),

              const SizedBox(height: 24),

              // Computed Zodiac
              const Text(
                'Your zodiac',
                style: TextStyle(color: AppColors.hintPurple, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _computedZodiac,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Preferred Signs
              const Text(
                'Preferred signs (tap to select)',
                style: TextStyle(color: AppColors.hintPurple, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AstrologyUtils.zodiacSigns.map((sign) {
                  final isSelected = _selectedSigns.contains(sign);
                  return FilterChip(
                    label: Text(sign),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSigns.add(sign);
                        } else {
                          _selectedSigns.remove(sign);
                        }
                      });
                    },
                    backgroundColor: AppColors.inputBackground,
                    selectedColor: AppColors.purplePrimary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.hintPurple,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Preferred Element
              DropdownButtonFormField<String>(
                value: _selectedElement,
                decoration: const InputDecoration(
                  labelText: 'Preferred element',
                ),
                dropdownColor: AppColors.inputBackground,
                items: AstrologyUtils.elements
                    .map((element) => DropdownMenuItem(
                          value: element,
                          child: Text(
                            element,
                            style: const TextStyle(color: AppColors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedElement = value);
                },
              ),

              const SizedBox(height: 16),

              // Lucky Number
              TextField(
                controller: _luckyNumberController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                style: const TextStyle(color: AppColors.inputTextWhite),
                decoration: const InputDecoration(
                  labelText: 'Lucky number (optional)',
                  counterText: '',
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveToFirebase,
                    child: const Text('Save'),
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