import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_language.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String? _selected;

  Future<void> _onContinue() async {
    if (_selected == null) return;

    await AppLanguage.setLanguage(_selected!);

    if (mounted) {
      context.go('/google-sign-in');
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
              const SizedBox(height: 24),

              LocalizedText(
                'अपनी भाषा चुनें / Choose Your Language',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: AppLanguage.languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _buildLanguageCard(
                    context: context,
                    language: AppLanguage.languages[index],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Continue Button
              FilledButton(
                onPressed: _selected != null ? _onContinue : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const LocalizedText('जारी रखें / Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required AppLocaleInfo language,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selected == language.code;

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
        onTap: language.available
            ? () {
                setState(() {
                  _selected = language.code;
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Icon(
              Icons.translate,
              color: language.available
                  ? colorScheme.primary
                  : colorScheme.outline,
            ),
            title: Text(
              language.nativeName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : language.available
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              language.available
                  ? language.englishName
                  : '${language.englishName} — translation unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Radio<String>(
              value: language.code,
              groupValue: _selected,
              onChanged: language.available
                  ? (String? newValue) {
                      setState(() {
                        _selected = newValue;
                      });
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
