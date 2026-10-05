import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:availchat/managers/filter_preferences.dart';
import 'package:availchat/services/location_service.dart';

import '../../features/onboarding/discovery_onboarding.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/custom_button.dart';

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
  bool _saveSuccess = false;
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
    // Local prefs and the users/{uid} read run in parallel.
    final (prefs, discoveryEnabled) = await (
      FilterPreferences.getInstance(),
      _loadDiscoveryEnabled(),
    ).wait;
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
    if (_saveSuccess) return;
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
        final write =
            FirebaseFirestore.instance.collection('users').doc(uid).set({
          'discoveryEnabled': _discoveryEnabled,
          'discoveryPendingOnboarding': FieldValue.delete(),
        }, SetOptions(merge: true));
        // Offline the write is queued and applied locally; a server ack
        // never comes, so wait briefly for real errors only.
        await write.timeout(const Duration(seconds: 5), onTimeout: () {});
      }

      if (!mounted) return;
      _saved = _current;
      Haptics.success();
      setState(() {
        _saving = false;
        _saveSuccess = true;
      });
      // Brief check-mark state before leaving.
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Discovery settings save failed: $e');
      if (!mounted) return;
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't save your settings. Check your connection and try again.",
          ),
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
        content: Text('Filters cleared. Tap Save & apply to keep the change.'),
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
          action: 'Open settings',
          onOpen: LocationService.instance.openLocationSettings,
        );
        break;
      case LocationUpdateResult.permanentlyDenied:
        await _settingsDialog(
          title: 'Location permission needed',
          message:
              'Location access is turned off for Destined. Allow it in Settings to use distance filters.',
          action: 'Open settings',
          onOpen: LocationService.instance.openAppSettings,
        );
        break;
      case LocationUpdateResult.denied:
        _snack(
          "Location access wasn't allowed, so your location wasn't updated.",
        );
        break;
      case LocationUpdateResult.notSignedIn:
      case LocationUpdateResult.failed:
        _snack(
          "Couldn't get your location. Check that location is on and try again.",
        );
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
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.lavender),
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
        title: const Text('Discard changes?'),
        content: const Text(
          'Your changes have not been saved.',
          style: TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
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
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        opacity: _applyFilters ? 1 : 0.4,
        child: child,
      ),
    );
  }

  /// One labelled filter block inside the FILTERS card.
  Widget _filterBlock({
    required Key key,
    required String label,
    String? value,
    required Widget child,
  }) {
    return _filterControl(
      child: Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (value != null)
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.brandPurpleLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _scale(String min, String max) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(min, style: _captionStyle),
          Text(max, style: _captionStyle),
        ],
      ),
    );
  }

  static const TextStyle _captionStyle = TextStyle(
    color: AppColors.textSubtle,
    fontSize: 12,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPurple),
        ),
      );
    }

    final dirty = _dirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !mounted) return;
        _saved = _current;
        Navigator.pop(this.context);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        appBar: AppBar(
          title: const Text('Discovery'),
          actions: [
            if (dirty) const _UnsavedPill(),
            IconButton(
              icon: const Icon(Icons.help_outline, color: AppColors.lavender),
              onPressed: () => DiscoveryOnboarding.showManually(context),
              tooltip: 'Show tutorial',
            ),
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
          ],
        ),
        // Cap width on tablets so the form stays readable.
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                const _GroupLabel('Visibility', first: true),
                _Group(
                  children: [
                    _SwitchRow(
                      key: DiscoveryOnboarding.discoveryToggleKey,
                      leading: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.brandPurpleLight,
                      ),
                      title: 'Show me on Discover',
                      value: _discoveryEnabled,
                      onChanged: (v) => setState(() => _discoveryEnabled = v),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        'Let other people see your profile in their Discover '
                        'feed.',
                        style: TextStyle(
                          color: AppColors.lavender,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const _GroupLabel('Filters'),
                _Group(
                  children: [
                    _SwitchRow(
                      key: DiscoveryOnboarding.filtersToggleKey,
                      leading: const Icon(
                        Icons.filter_list,
                        size: 18,
                        color: AppColors.brandPurpleLight,
                      ),
                      title: 'Apply discovery filters',
                      subtitle: 'Use the filters below while browsing',
                      value: _applyFilters,
                      onChanged: (v) => setState(() => _applyFilters = v),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _filterBlock(
                      key: DiscoveryOnboarding.genderFilterKey,
                      label: 'Show me',
                      child: _Segmented(
                        value: _showMeGender,
                        options: const {
                          'everyone': 'Everyone',
                          'male': 'Men',
                          'female': 'Women',
                        },
                        onChanged: (v) => setState(() => _showMeGender = v),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _filterBlock(
                      key: DiscoveryOnboarding.ageFilterKey,
                      label: 'Age range',
                      value:
                          '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RangeSlider(
                            values: _ageRange,
                            onChanged: (v) => setState(() => _ageRange = v),
                            min: _minAge,
                            max: _maxAge,
                            divisions: 42,
                            semanticFormatterCallback: (v) =>
                                '${v.round()} years',
                          ),
                          _scale('${_minAge.round()}', '${_maxAge.round()}'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _filterBlock(
                      key: DiscoveryOnboarding.distanceFilterKey,
                      label: 'Distance',
                      value: 'Up to ${_distanceKm.round()} km',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Slider(
                            value: _distanceKm,
                            onChanged: (v) => setState(() => _distanceKm = v),
                            min: _minDistance,
                            max: _maxDistance,
                            divisions: 19,
                            semanticFormatterCallback: (v) =>
                                'Up to ${v.round()} km',
                          ),
                          _scale(
                            '${_minDistance.round()} km',
                            '${_maxDistance.round()} km',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _filterControl(
                      child: _SwitchRow(
                        key: DiscoveryOnboarding.onlineFilterKey,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.online,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.online.withOpacity(0.25),
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        title: 'Online only',
                        subtitle: 'Only people active right now',
                        value: _onlineOnly,
                        onChanged: (v) => setState(() => _onlineOnly = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomButton(
                  key: DiscoveryOnboarding.locationButtonKey,
                  text: 'Use current location',
                  type: ButtonType.outline,
                  size: ButtonSize.small,
                  leftIcon: Icons.my_location,
                  isLoading: _locating,
                  onPressed: _locating ? null : _useCurrentLocation,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: dirty
                            ? const Padding(
                                key: ValueKey('dirty'),
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'You have unsaved changes.',
                                  style: TextStyle(
                                    color: AppColors.lavender,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('clean')),
                      ),
                      CustomButton(
                        key: DiscoveryOnboarding.saveButtonKey,
                        text: 'Save & apply',
                        isLoading: _saving,
                        isSuccess: _saveSuccess,
                        onPressed: _saving ? null : _savePrefs,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 12 : 24, 8, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

/// 56dp row: icon tile, title/subtitle and a switch; the whole row toggles.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  void _toggle(bool v) {
    Haptics.selection();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return MergeSemantics(
      child: InkWell(
        onTap: () => _toggle(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandPurpleMid.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: leading,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: const TextStyle(
                            color: AppColors.lavender,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: value, onChanged: _toggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill segmented control (single choice).
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == value,
                inMutuallyExclusiveGroup: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    if (entry.key != value) Haptics.selection();
                    onChanged(entry.key);
                  },
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value
                          ? AppColors.surface2
                          : AppColors.surfaceRaised.withOpacity(0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: entry.key == value
                            ? AppColors.borderStrong
                            : AppColors.border.withOpacity(0),
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: entry.key == value
                            ? AppColors.white
                            : AppColors.lavender,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// App bar hint shown while the form has unsaved edits.
class _UnsavedPill extends StatelessWidget {
  const _UnsavedPill();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPink,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPink.withOpacity(0.22),
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Unsaved',
              style: TextStyle(
                color: AppColors.pinkLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
