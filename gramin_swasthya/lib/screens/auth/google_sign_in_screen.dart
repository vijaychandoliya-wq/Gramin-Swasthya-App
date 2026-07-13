import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/family_provider.dart';
import '../../services/auth_service.dart';

class GoogleSignInScreen extends ConsumerStatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  ConsumerState<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends ConsumerState<GoogleSignInScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingUser = AuthService.instance.currentUser;
      if (existingUser != null) _finishAccountSetup(existingUser);
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      await _finishAccountSetup(user);
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? 'Google sign-in failed. Please try again.');
    } catch (_) {
      _showError('Google sign-in failed. Please check your connection.');
    }
  }

  Future<void> _finishAccountSetup(User user) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    var phone = _normalisePhone(user.phoneNumber) ??
        prefs.getString('linked_phone_${user.uid}');

    if (phone == null || phone.length != 10) {
      phone = await _askForPhoneNumber();
      if (phone == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    await ref.read(familyProvider.notifier).ensureGooglePrimaryProfile(
          uid: user.uid,
          name: _accountName(user),
          email: user.email,
          phone: phone,
          photoUrl: user.photoURL,
        );

    await prefs.setString('linked_phone_${user.uid}', phone);
    await prefs.setString('account_setup_complete_uid', user.uid);

    if (mounted) context.go('/home');
  }

  Future<String?> _askForPhoneNumber() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.phone_android_rounded),
        title: const LocalizedText('Link your mobile number'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LocalizedText(
                'Google does not share your phone number. Enter it once to add it to your health profile. No OTP is required.\n\nगूगल आपका नंबर साझा नहीं करता। इसे अपनी प्रोफ़ाइल से जोड़ने के लिए एक बार दर्ज करें।',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: AppLanguage.text('Mobile number / मोबाइल नंबर'),
                  prefixText: AppLanguage.text('+91 '),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.length == 10
                    ? null
                    : 'Enter a valid 10-digit mobile number',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const LocalizedText('Continue / जारी रखें'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  String _accountName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'My Profile';
  }

  String? _normalisePhone(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset('assets/images/logo.svg'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  LocalizedText(
                    'Your health records, one secure account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  LocalizedText(
                    'Google से साइन इन करें। आपकी पहली स्वास्थ्य प्रोफ़ाइल आपके नाम, ईमेल और लिंक किए गए मोबाइल नंबर से अपने आप बन जाएगी।',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined,
                              color: colors.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: LocalizedText(
                              'Sign in only once. This phone remembers your account for future app launches.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    LocalizedText(
                      _errorMessage!,
                      style: TextStyle(color: colors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _signIn,
                    icon: _isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: LocalizedText(
                              'G',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    label: LocalizedText(
                        _isLoading ? 'Signing in…' : 'Continue with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LocalizedText(
                    'No password, PIN, or OTP required.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
