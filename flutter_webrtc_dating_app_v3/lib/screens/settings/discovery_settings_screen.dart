import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:availchat/managers/filter_preferences.dart';
import 'package:availchat/services/location_service.dart';

import '../../features/onboarding/discovery_onboarding.dart';

class DiscoverySettingsScreen extends StatefulWidget {
  const DiscoverySettingsScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverySettingsScreen> createState() =>
      _DiscoverySettingsScreenState();
}

/// Snapshot of the form, used to detect unsaved changes.
@immutable
class _DiscoveryForm {
  final bool discoveryEnabled;
  final bool applyFilters;
  final String showMeGender;
  final RangeValues ageRange;
  final double distanceKm;
  final bool onlineOnly;

  const _DiscoveryForm({
    required this.discoveryEnabled,
    required this.applyFilters,
    required this.showMeGender,
    required this.ageRange,
    required this.distanceKm,
    required this.onlineOnly,
  });

  @override
  bool operator ==(Object other) =>
      other is _DiscoveryForm &&
      other.discoveryEnabled == discoveryEnabled &&
      other.applyFilters == applyFilters &&
      other.showMeGender == showMeGender &&
      other.ageRange == ageRange &&
      other.distanceKm == distanceKm &&
      other.onlineOnly == onlineOnly;

  @override
  int get hashCode => Object.hash(
    discoveryEnabled,
    applyFilters,
    showMeGender,
    ageRange,
    distanceKm,
    onlineOnly,
  );
}

class _DiscoverySettingsScreenState extends State<DiscoverySettingsScreen> {
  static const double _minAge = 18;
  static const double _maxAge = 60;
  static const double _minDistance = 5;
  static const double _maxDistance = 100;

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;

  bool _discoveryEnabled = false;
  bool _applyFilters = false;
  String _showMeGender = 'everyone';
  RangeValues _ageRange = const RangeValues(_minAge, _maxAge);
  double _distanceKm = _maxDistance;
  bool _onlineOnly = false;

  _DiscoveryForm? _saved;

  _DiscoveryForm get _current => _DiscoveryForm(
    discoveryEnabled: _discoveryEnabled,
    applyFilters: _applyFilters,
    showMeGender: _showMeGender,
    ageRange: _ageRange,
    distanceKm: _distanceKm,
    onlineOnly: _onlineOnly,
  );

  bool get _dirty => _saved != null && _saved != _current;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await FilterPreferences.getInstance();
    final discoveryEnabled = await _loadDiscoveryEnabled();
    if (!mounted) return;
    setState(() {
      _discoveryEnabled = discoveryEnabled;
      _applyFilters = prefs.applyFilters;
      _showMeGender =
          const ['everyone', 'male', 'female'].contains(prefs.showMeGender)
          ? prefs.showMeGender
          : 'everyone';
      _ageRange = RangeValues(prefs.ageMin.toDouble(), prefs.ageMax.toDouble());
      _distanceKm = prefs.distanceKm.toDouble().clamp(
        _minDistance,
        _maxDistance,
      );
      _onlineOnly = prefs.onlineOnly;
      _saved = _current;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DiscoveryOnboarding.tryShow(context);
      }
    });
  }

  /// Visibility is account state, so it is read from users/{uid}.
  Future<bool> _loadDiscoveryEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 5));
      return snap.data()?['discoveryEnabled'] == true;
    } catch (_) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        return cached.data()?['discoveryEnabled'] == true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _savePrefs() async {
    final saved = _saved;
    setState(() => _saving = true);
    try {
      final prefs = await FilterPreferences.getInstance();
      await prefs.saveAll(
        applyFilters: _applyFilters,
        showMeGender: _showMeGender,
        ageMin: _ageRange.start.round(),
        ageMax: _ageRange.end.round(),
        distanceKm: _distanceKm.round(),
        onlineOnly: _onlineOnly,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && saved?.discoveryEnabled != _discoveryEnabled) {
        // An explicit choice replaces the "turn on after onboarding" flag.
        final write = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'discoveryEnabled': _discoveryEnabled,
              'discoveryPendingOnboarding': FieldValue.delete(),
            }, SetOptions(merge: true));
        // Offline the write is queued and applied locally; a server ack
        // never comes, so wait briefly for real errors only.
        await write.timeout(const Duration(seconds: 5), onTimeout: () {});
      }

      if (!mounted) return;
      _saved = _current;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Discovery settings save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your settings. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _applyFilters = false;
      _showMeGender = 'everyone';
      _ageRange = const RangeValues(_minAge, _maxAge);
      _distanceKm = _maxDistance;
      _onlineOnly = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filters reset. Tap Save & Apply to confirm.'),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.instance.updateCurrentLocation(
      force: true,
    );
    if (!mounted) return;
    setState(() => _locating = false);

    switch (result) {
      case LocationUpdateResult.updated:
      case LocationUpdateResult.fresh:
        _snack('Location updated');
        break;
      case LocationUpdateResult.serviceDisabled:
        await _settingsDialog(
          title: 'Location is off',
          message: 'Turn on location services to find people near you.',
          action: 'Open Settings',
          onOpen: LocationService.instance.openLocationSettings,
        );
        break;
      case LocationUpdateResult.permanentlyDenied:
        await _settingsDialog(
          title: 'Location permission needed',
          message:
              'Location access is turned off for Destined. Allow it in Settings to use distance filters.',
          action: 'Open Settings',
          onOpen: LocationService.instance.openAppSettings,
        );
        break;
      case LocationUpdateResult.denied:
        _snack('Location permission denied');
        break;
      case LocationUpdateResult.notSignedIn:
      case LocationUpdateResult.failed:
        _snack('Could not get your location. Please try again.');
        break;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _settingsDialog({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() onOpen,
  }) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFB39DDB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (open == true) await onOpen();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text(
          'Discard changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your changes have not been saved.',
          style: TextStyle(color: Color(0xFFB39DDB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  /// Dims and disables a filter control while filters are off.
  Widget _filterControl({required Widget child}) {
    return IgnorePointer(
      ignoring: !_applyFilters,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _applyFilters ? 1 : 0.4,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A0E2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !mounted) return;
        _saved = _current;
        Navigator.pop(this.context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0E2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D1B4E),
          title: const Text('Discovery Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white70),
              onPressed: () => DiscoveryOnboarding.showManually(context),
              tooltip: 'Show Tutorial',
            ),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // =========================================================
            // STEP 1: Show me on Discover
            // =========================================================
            SwitchListTile(
              key: DiscoveryOnboarding.discoveryToggleKey,
              value: _discoveryEnabled,
              onChanged: (v) => setState(() => _discoveryEnabled = v),
              activeColor: const Color(0xFF7B2CBF),
              title: const Text(
                'Show me on Discover',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Let other people see your profile in their Discover feed',
                style: TextStyle(color: Color(0xFFB39DDB)),
              ),
            ),
            const SizedBox(height: 12),

            // =========================================================
            // STEP 2: Apply Discovery Filters
            // =========================================================
            SwitchListTile(
              key: DiscoveryOnboarding.filtersToggleKey,
              value: _applyFilters,
              onChanged: (v) => setState(() => _applyFilters = v),
              activeColor: const Color(0xFF7B2CBF),
              title: const Text(
                'Apply Discovery Filters',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Use the gender, age, distance and online filters below while browsing',
                style: TextStyle(color: Color(0xFFB39DDB)),
              ),
            ),
            const SizedBox(height: 16),

            // =========================================================
            // STEP 3: Gender Dropdown (SEPARATE KEY)
            // =========================================================
            _filterControl(
              child: Container(
                key: DiscoveryOnboarding.genderFilterKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Show me',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _showMeGender,
                      dropdownColor: const Color(0xFF2D1B4E),
                      decoration: _inputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'everyone',
                          child: Text(
                            'Everyone',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'male',
                          child: Text(
                            'Men',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text(
                            'Women',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _showMeGender = v ?? 'everyone'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // =========================================================
            // STEP 4: Age Range (SEPARATE KEY)
            // =========================================================
            _filterControl(
              child: Container(
                key: DiscoveryOnboarding.ageFilterKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Age range',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                          style: const TextStyle(color: Color(0xFFB39DDB)),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _ageRange,
                      onChanged: (v) => setState(() => _ageRange = v),
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: const Color(0xFF7B2CBF),
                      inactiveColor: const Color(0xFF7B2CBF).withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // =========================================================
            // STEP 5: Distance (SEPARATE KEY)
            // =========================================================
            _filterControl(
              child: Container(
                key: DiscoveryOnboarding.distanceFilterKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distance (km)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_distanceKm.round()} km',
                          style: const TextStyle(color: Color(0xFFB39DDB)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _distanceKm,
                      onChanged: (v) => setState(() => _distanceKm = v),
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: const Color(0xFF7B2CBF),
                      inactiveColor: const Color(0xFF7B2CBF).withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // =========================================================
            // STEP 6: Online Only (SEPARATE KEY)
            // =========================================================
            _filterControl(
              child: Container(
                key: DiscoveryOnboarding.onlineFilterKey,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  ),
                ),
                child: SwitchListTile(
                  value: _onlineOnly,
                  onChanged: (v) => setState(() => _onlineOnly = v),
                  activeColor: const Color(0xFF7B2CBF),
                  title: const Text(
                    'Online only',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Show only users currently online',
                    style: TextStyle(color: Color(0xFFB39DDB)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // =========================================================
            // STEP 7: Location Button
            // =========================================================
            OutlinedButton.icon(
              key: DiscoveryOnboarding.locationButtonKey,
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFF7B2CBF),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF7B2CBF)),
              label: const Text(
                'Use Current Location',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7B2CBF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // =========================================================
            // STEP 8: Save Button
            // =========================================================
            SizedBox(
              key: DiscoveryOnboarding.saveButtonKey,
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _savePrefs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save & Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF2D1B4E),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF7B2CBF)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF7B2CBF)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
