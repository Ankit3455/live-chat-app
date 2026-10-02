import 'package:flutter/material.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  int? _selectedAvatar;

  // Emoji avatars (you can replace with actual images)
  final List<String> _avatars = [
    '😀', '😎', '🥳', '😍', '🤩', '😇',
    '🤓', '😏', '🥰', '😊', '🙂', '😃',
    '😄', '😁', '😆', '🤣', '😂', '🙃',
    '😉', '😌', '😋', '😛', '😝', '😜',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        title: const Text('Choose Your Avatar'),
        backgroundColor: const Color(0xFF2D1B4E),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _avatars.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedAvatar == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatar = index;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7B2CBF)
                          : const Color(0xFF2D1B4E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7B2CBF)
                            : const Color(0xFF2D1B4E),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _avatars[index],
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedAvatar != null
                    ? () => Navigator.pop(context, _selectedAvatar)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  disabledBackgroundColor: const Color(0xFF2D1B4E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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