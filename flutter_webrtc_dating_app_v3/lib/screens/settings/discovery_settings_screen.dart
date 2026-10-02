// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:availchat/managers/filter_preferences.dart';
//
// class DiscoverySettingsScreen extends StatefulWidget {
//   const DiscoverySettingsScreen({Key? key}) : super(key: key);
//
//   @override
//   State<DiscoverySettingsScreen> createState() => _DiscoverySettingsScreenState();
// }
//
// class _DiscoverySettingsScreenState extends State<DiscoverySettingsScreen> {
//   bool _loading = true;
//   bool _saving = false;
//
//   // Toggles/Filters
//   bool _discoveryEnabled = true; // aapki visibility (Firestore)
//   bool _applyFilters = false;     // browsing filters (local)
//   String _showMeGender = 'everyone';
//   RangeValues _ageRange = const RangeValues(18, 60);
//   double _distanceKm = 100;
//   bool _onlineOnly = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPrefs();
//   }
//
//   Future<void> _loadPrefs() async {
//     final prefs = await FilterPreferences.getInstance();
//     setState(() {
//       _discoveryEnabled = prefs.discoveryEnabled;
//       _applyFilters = prefs.applyFilters;
//       _showMeGender = prefs.showMeGender;
//       _ageRange = RangeValues(prefs.ageMin.toDouble(), prefs.ageMax.toDouble());
//       _distanceKm = prefs.distanceKm.toDouble();
//       _onlineOnly = prefs.onlineOnly;
//       _loading = false;
//     });
//   }
//
//   Future<void> _savePrefs() async {
//     setState(() => _saving = true);
//     final prefs = await FilterPreferences.getInstance();
//     await prefs.setDiscoveryEnabled(_discoveryEnabled);
//     await prefs.setApplyFilters(_applyFilters);
//     await prefs.setShowMeGender(_showMeGender);
//     await prefs.setAgeMin(_ageRange.start.round());
//     await prefs.setAgeMax(_ageRange.end.round());
//     await prefs.setDistanceKm(_distanceKm.round());
//     await prefs.setOnlineOnly(_onlineOnly);
//
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid != null) {
//       await FirebaseFirestore.instance.collection('users').doc(uid).set(
//         {'discoveryEnabled': _discoveryEnabled},
//         SetOptions(merge: true),
//       );
//     }
//
//     if (mounted) {
//       setState(() => _saving = false);
//       Navigator.pop(context, true);
//     }
//   }
//
//   void _clearFilters() {
//     setState(() {
//       _discoveryEnabled = true;
//       _applyFilters = false;
//       _showMeGender = 'everyone';
//       _ageRange = const RangeValues(18, 60);
//       _distanceKm = 100;
//       _onlineOnly = false;
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Filters reset — Save & Apply to confirm')),
//     );
//   }
//
//   Future<void> _useCurrentLocation() async {
//     try {
//       final status = await Permission.location.request();
//       if (!status.isGranted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Location permission denied')),
//         );
//         return;
//       }
//
//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid != null) {
//         await FirebaseFirestore.instance.collection('users').doc(uid).set(
//           {
//             'userLatitude': position.latitude,
//             'userLongitude': position.longitude,
//             'lastLocationUpdate': DateTime.now().millisecondsSinceEpoch,
//           },
//           SetOptions(merge: true),
//         );
//       }
//
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Location updated')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Location error: $e')),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Scaffold(
//         backgroundColor: Color(0xFF1A0E2E),
//         body: Center(child: CircularProgressIndicator(color: Color(0xFF7B2CBF))),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF1A0E2E),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2D1B4E),
//         title: const Text('Discovery Settings'),
//         actions: [
//           TextButton(
//             onPressed: _clearFilters,
//             child: const Text('Clear', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // Toggle 1: Show me on Discover
//           SwitchListTile(
//             value: _discoveryEnabled,
//             onChanged: (v) => setState(() => _discoveryEnabled = v),
//             activeColor: const Color(0xFF7B2CBF),
//             title: const Text('Show me on Discover', style: TextStyle(color: Colors.white)),
//             subtitle: const Text(
//               'Dusron ki Discover feed me aapka profile dikhana/na dikhana',
//               style: TextStyle(color: Color(0xFFB39DDB)),
//             ),
//           ),
//           const SizedBox(height: 12),
//
//           // Toggle 2: Apply Discovery Filters
//           SwitchListTile(
//             value: _applyFilters,
//             onChanged: (v) => setState(() => _applyFilters = v),
//             activeColor: const Color(0xFF7B2CBF),
//             title: const Text('Apply Discovery Filters', style: TextStyle(color: Colors.white)),
//             subtitle: const Text(
//               'Browsing ke dauran gender, age, distance, online-only aur search apply kare',
//               style: TextStyle(color: Color(0xFFB39DDB)),
//             ),
//           ),
//           const SizedBox(height: 12),
//
//           const Text('Show me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             value: _showMeGender,
//             dropdownColor: const Color(0xFF2D1B4E),
//             decoration: _inputDecoration(),
//             items: const [
//               DropdownMenuItem(value: 'everyone', child: Text('Everyone', style: TextStyle(color: Colors.white))),
//               DropdownMenuItem(value: 'male', child: Text('Men', style: TextStyle(color: Colors.white))),
//               DropdownMenuItem(value: 'female', child: Text('Women', style: TextStyle(color: Colors.white))),
//             ],
//             onChanged: (v) => setState(() => _showMeGender = v ?? 'everyone'),
//           ),
//           const SizedBox(height: 16),
//
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Age range', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               Text('${_ageRange.start.round()} - ${_ageRange.end.round()}',
//                   style: const TextStyle(color: Color(0xFFB39DDB))),
//             ],
//           ),
//           RangeSlider(
//             values: _ageRange,
//             onChanged: (v) => setState(() => _ageRange = v),
//             min: 18,
//             max: 60,
//             divisions: 42,
//             activeColor: const Color(0xFF7B2CBF),
//             inactiveColor: const Color(0xFF7B2CBF),
//           ),
//           const SizedBox(height: 16),
//
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Distance (km)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               Text('${_distanceKm.round()} km', style: const TextStyle(color: Color(0xFFB39DDB))),
//             ],
//           ),
//           Slider(
//             value: _distanceKm,
//             onChanged: (v) => setState(() => _distanceKm = v),
//             min: 5,
//             max: 100,
//             divisions: 19,
//             activeColor: const Color(0xFF7B2CBF),
//             inactiveColor: const Color(0xFF7B2CBF),
//           ),
//           const SizedBox(height: 8),
//
//           SwitchListTile(
//             value: _onlineOnly,
//             onChanged: (v) => setState(() => _onlineOnly = v),
//             activeColor: const Color(0xFF7B2CBF),
//             title: const Text('Online only', style: TextStyle(color: Colors.white)),
//             subtitle: const Text('Show only users currently online',
//                 style: TextStyle(color: Color(0xFFB39DDB))),
//           ),
//           const SizedBox(height: 16),
//
//           OutlinedButton.icon(
//             onPressed: _useCurrentLocation,
//             icon: const Icon(Icons.my_location, color: Color(0xFF7B2CBF)),
//             label: const Text('Use Current Location', style: TextStyle(color: Colors.white)),
//             style: OutlinedButton.styleFrom(
//               side: const BorderSide(color: Color(0xFF7B2CBF)),
//               padding: const EdgeInsets.symmetric(vertical: 14),
//             ),
//           ),
//           const SizedBox(height: 24),
//
//           SizedBox(
//             width: double.infinity,
//             height: 50,
//             child: ElevatedButton(
//               onPressed: _saving ? null : _savePrefs,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF7B2CBF),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//               child: _saving
//                   ? const SizedBox(
//                   width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                   : const Text('Save & Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   InputDecoration _inputDecoration() {
//     return InputDecoration(
//       filled: true,
//       fillColor: const Color(0xFF2D1B4E),
//       enabledBorder: OutlineInputBorder(
//         borderSide: const BorderSide(color: Color(0xFF7B2CBF)),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderSide: const BorderSide(color: Color(0xFF7B2CBF)),
//         borderRadius: BorderRadius.circular(12),
//       ),
//     );
//   }
// }


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:availchat/managers/filter_preferences.dart';

import '../../features/onboarding/discovery_onboarding.dart';

class DiscoverySettingsScreen extends StatefulWidget {
  const DiscoverySettingsScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverySettingsScreen> createState() =>
      _DiscoverySettingsScreenState();
}

class _DiscoverySettingsScreenState extends State<DiscoverySettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  bool _discoveryEnabled = true;
  bool _applyFilters = false;
  String _showMeGender = 'everyone';
  RangeValues _ageRange = const RangeValues(18, 60);
  double _distanceKm = 100;
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await FilterPreferences.getInstance();
    setState(() {
      _discoveryEnabled = prefs.discoveryEnabled;
      _applyFilters = prefs.applyFilters;
      _showMeGender = prefs.showMeGender;
      _ageRange =
          RangeValues(prefs.ageMin.toDouble(), prefs.ageMax.toDouble());
      _distanceKm = prefs.distanceKm.toDouble();
      _onlineOnly = prefs.onlineOnly;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DiscoveryOnboarding.tryShow(context);
      }
    });
  }

  Future<void> _savePrefs() async {
    setState(() => _saving = true);
    final prefs = await FilterPreferences.getInstance();
    await prefs.setDiscoveryEnabled(_discoveryEnabled);
    await prefs.setApplyFilters(_applyFilters);
    await prefs.setShowMeGender(_showMeGender);
    await prefs.setAgeMin(_ageRange.start.round());
    await prefs.setAgeMax(_ageRange.end.round());
    await prefs.setDistanceKm(_distanceKm.round());
    await prefs.setOnlineOnly(_onlineOnly);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'discoveryEnabled': _discoveryEnabled},
        SetOptions(merge: true),
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  void _clearFilters() {
    setState(() {
      _discoveryEnabled = true;
      _applyFilters = false;
      _showMeGender = 'everyone';
      _ageRange = const RangeValues(18, 60);
      _distanceKm = 100;
      _onlineOnly = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filters reset — Save & Apply to confirm')),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'userLatitude': position.latitude,
            'userLongitude': position.longitude,
            'lastLocationUpdate': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A0E2E),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7B2CBF))),
      );
    }

    return Scaffold(
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
            title: const Text('Show me on Discover',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Dusron ki Discover feed me aapka profile dikhana/na dikhana',
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
            title: const Text('Apply Discovery Filters',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Browsing ke dauran gender, age, distance, online-only aur search apply kare',
              style: TextStyle(color: Color(0xFFB39DDB)),
            ),
          ),
          const SizedBox(height: 16),

          // =========================================================
          // STEP 3: Gender Dropdown (SEPARATE KEY)
          // =========================================================
          Container(
            key: DiscoveryOnboarding.genderFilterKey, // ⭐ NEW KEY
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B4E).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Show me',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _showMeGender,
                  dropdownColor: const Color(0xFF2D1B4E),
                  decoration: _inputDecoration(),
                  items: const [
                    DropdownMenuItem(
                        value: 'everyone',
                        child: Text('Everyone',
                            style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(
                        value: 'male',
                        child:
                        Text('Men', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(
                        value: 'female',
                        child: Text('Women',
                            style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) =>
                      setState(() => _showMeGender = v ?? 'everyone'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // =========================================================
          // STEP 4: Age Range (SEPARATE KEY)
          // =========================================================
          Container(
            key: DiscoveryOnboarding.ageFilterKey, // ⭐ NEW KEY
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B4E).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Age range',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                        '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                        style: const TextStyle(color: Color(0xFFB39DDB))),
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
          const SizedBox(height: 12),

          // =========================================================
          // STEP 5: Distance (SEPARATE KEY)
          // =========================================================
          Container(
            key: DiscoveryOnboarding.distanceFilterKey, // ⭐ NEW KEY
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B4E).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Distance (km)',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${_distanceKm.round()} km',
                        style: const TextStyle(color: Color(0xFFB39DDB))),
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
          const SizedBox(height: 12),

          // =========================================================
          // STEP 6: Online Only (SEPARATE KEY)
          // =========================================================
          Container(
            key: DiscoveryOnboarding.onlineFilterKey, // ⭐ NEW KEY
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B4E).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2)),
            ),
            child: SwitchListTile(
              value: _onlineOnly,
              onChanged: (v) => setState(() => _onlineOnly = v),
              activeColor: const Color(0xFF7B2CBF),
              title: const Text('Online only',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Show only users currently online',
                  style: TextStyle(color: Color(0xFFB39DDB))),
            ),
          ),
          const SizedBox(height: 16),

          // =========================================================
          // STEP 7: Location Button
          // =========================================================
          OutlinedButton.icon(
            key: DiscoveryOnboarding.locationButtonKey,
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location, color: Color(0xFF7B2CBF)),
            label: const Text('Use Current Location',
                style: TextStyle(color: Colors.white)),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Save & Apply',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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