import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/family_provider.dart';

class AddMemberScreen extends ConsumerStatefulWidget {
  final FamilyMember? member;
  const AddMemberScreen({super.key, this.member});

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _contactNameController;
  late TextEditingController _phoneController;

  String _gender = 'पुरुष / Male';
  String _bloodGroup = 'O+';
  String? _photoPath;
  final Set<String> _selectedDiseases = {};

  final List<String> _diseaseOptions = [
    "मधुमेह / Diabetes",
    "BP (Hypertension)",
    "हृदय रोग / Heart Disease",
    "थायराइड / Thyroid",
    "अस्थमा / Asthma",
    "गुर्दे की बीमारी / Kidney Disease",
    "अन्य / Other"
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameController = TextEditingController(text: m?.name ?? '');
    _ageController = TextEditingController(text: m?.age.toString() ?? '');
    _contactNameController =
        TextEditingController(text: m?.emergencyContactName ?? '');
    _phoneController = TextEditingController(text: m?.emergencyPhone ?? '');

    if (m != null) {
      _gender = m.gender;
      _bloodGroup = m.bloodGroup;
      _photoPath = m.photoPath;
      _selectedDiseases.addAll(m.diseases);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _photoPath = image.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text) ?? 0;
    final contactName = _contactNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (widget.member == null) {
      await ref.read(familyProvider.notifier).addMember(
            name: name,
            relation: 'Family',
            age: age,
            gender: _gender,
            bloodGroup: _bloodGroup,
            photoPath: _photoPath,
            diseases: _selectedDiseases.toList(),
            emergencyContactName: contactName,
            emergencyPhone: phone,
          );
    } else {
      final updated = FamilyMember(
        id: widget.member!.id,
        name: name,
        relation: widget.member!.relation,
        age: age,
        gender: _gender,
        bloodGroup: _bloodGroup,
        photoPath: _photoPath,
        photoUrl: widget.member!.photoUrl,
        phone: widget.member!.phone,
        email: widget.member!.email,
        ownerUid: widget.member!.ownerUid,
        diseases: _selectedDiseases.toList(),
        emergencyContactName: contactName,
        emergencyPhone: phone,
        isPrimary: widget.member!.isPrimary,
      );
      await ref.read(familyProvider.notifier).updateMember(updated);
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.member != null;

    return Scaffold(
      appBar: AppBar(
        title: LocalizedText(isEditing ? "सदस्य संपादित करें" : "सदस्य जोड़ें"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo Section
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: colorScheme.primaryContainer,
                        child: _photoPath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_photoPath!),
                                  width: 112,
                                  height: 112,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : widget.member?.photoUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      widget.member!.photoUrl!,
                                      width: 112,
                                      height: 112,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(Icons.person_outline,
                                    size: 56,
                                    color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primary,
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Section 1: Basic Info
              _buildSectionHeader("बुनियादी जानकारी / Basic Info"),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: AppLanguage.text('नाम / Name *'),
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'नाम आवश्यक है' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: InputDecoration(
                                labelText: AppLanguage.text('उम्र / Age'),
                                suffixText: AppLanguage.text('वर्ष'),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: AppLanguage.text('लिंग / Gender'),
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12),
                              ),
                              items: [
                                'पुरुष / Male',
                                'महिला / Female',
                                'अन्य / Other'
                              ]
                                  .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: LocalizedText(g,
                                          style:
                                              const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setState(() => _gender = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration: InputDecoration(
                          labelText:
                              AppLanguage.text('रक्त समूह / Blood Group'),
                          prefixIcon: Icon(Icons.water_drop, color: Colors.red),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'अज्ञात / Unknown',
                          'A+',
                          'A-',
                          'B+',
                          'B-',
                          'AB+',
                          'AB-',
                          'O+',
                          'O-'
                        ]
                            .map((bg) => DropdownMenuItem(
                                value: bg, child: LocalizedText(bg)))
                            .toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v!),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: Health Info
              _buildSectionHeader("स्वास्थ्य जानकारी / Health Info"),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText("मौजूदा बीमारियाँ / Conditions",
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 0,
                        children: _diseaseOptions.map((d) {
                          final isSelected = _selectedDiseases.contains(d);
                          return FilterChip(
                            label: LocalizedText(d,
                                style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedDiseases.add(d);
                                } else {
                                  _selectedDiseases.remove(d);
                                }
                              });
                            },
                            selectedColor: colorScheme.errorContainer,
                            checkmarkColor: colorScheme.error,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 3: Emergency Contact
              _buildSectionHeader("आपातकालीन संपर्क / Emergency"),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _contactNameController,
                        decoration: InputDecoration(
                          labelText:
                              AppLanguage.text('संपर्क नाम / Contact Name'),
                          prefixIcon: Icon(Icons.person_pin_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: AppLanguage.text('फोन नंबर / Phone *'),
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ],
                        validator: (v) => (v == null || v.length != 10)
                            ? '10 अंकों का नंबर आवश्यक है'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: LocalizedText(
                  isEditing ? "Save Changes" : "Add Member",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              if (isEditing) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _confirmDelete(ref, widget.member!),
                  style:
                      TextButton.styleFrom(foregroundColor: colorScheme.error),
                  child: const LocalizedText("सदस्य हटाएं / Delete Member"),
                ),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: LocalizedText(title,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }

  Future<void> _confirmDelete(WidgetRef ref, FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('${member.name} को हटाएं?'),
        content:
            const LocalizedText('क्या आप वाकई इस प्रोफाइल को हटाना चाहते हैं?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const LocalizedText('रद्द')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('हटाएं'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(familyProvider.notifier).deleteMember(member.id);
      if (mounted) {
        context.pop();
      }
    }
  }
}
