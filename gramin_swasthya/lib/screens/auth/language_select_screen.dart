import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String? _selected; // null by default

  Future<void> _onContinue() async {
    if (_selected == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selected!);
    
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48), // Spacer for top
              
              Text(
                'अपनी भाषा चुनें',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose Your Language',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // Card 1 (Hindi)
              _buildLanguageCard(
                context: context,
                value: 'hi',
                emoji: '🇮🇳',
                title: 'हिंदी',
                subtitle: 'Hindi',
              ),
              
              const SizedBox(height: 16),
              
              // Card 2 (English)
              _buildLanguageCard(
                context: context,
                value: 'en',
                emoji: '🇬🇧',
                title: 'English',
                subtitle: 'अंग्रेज़ी',
              ),

              const Spacer(),
              
              // Continue Button
              FilledButton(
                onPressed: _selected != null ? _onContinue : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('जारी रखें / Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String value,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selected == value;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selected = value;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.8) : colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Radio<String>(
              value: value,
              groupValue: _selected,
              onChanged: (String? newValue) {
                setState(() {
                  _selected = newValue;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
