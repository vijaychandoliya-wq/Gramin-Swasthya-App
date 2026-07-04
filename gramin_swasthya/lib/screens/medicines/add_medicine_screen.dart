import 'package:flutter/material.dart';
import '../../utils/snackbar_helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notifications_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/medicines_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/notification_service.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  final Medicine? medicine;
  const AddMedicineScreen({super.key, this.medicine});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedUnit = 'Tablet';
  List<TimeOfDay> _selectedTimes = [];
  int _durationDays = -1; // -1 for Always
  DateTime _startDate = DateTime.now();
  bool _isActive = true;

  final List<String> _units = ["mg", "ml", "Tablet", "Capsule", "Drops", "IU", "Units"];

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _selectedUnit = widget.medicine!.unit;
      _selectedTimes = List.from(widget.medicine!.times);
      _isActive = widget.medicine!.isActive;
      // Note: duration and start date from history/schema if added in future
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isFormValid => _nameController.text.isNotEmpty && _selectedTimes.isNotEmpty;

  void _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && !_selectedTimes.contains(picked)) {
      setState(() => _selectedTimes.add(picked));
    }
  }

  void _removeTime(TimeOfDay time) {
    setState(() => _selectedTimes.remove(time));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_isFormValid) return;

    final selectedMember = ref.read(selectedFamilyMemberProvider);
    final repo = ref.read(medicinesRepoProvider);

    final medicine = Medicine(
      id: widget.medicine?.id ?? const Uuid().v4(),
      memberId: selectedMember?.id ?? '1',
      name: _nameController.text,
      dosage: _dosageController.text,
      unit: _selectedUnit,
      times: _selectedTimes,
      isActive: _isActive,
      durationDays: _durationDays,
      startDate: _startDate,
      takenHistory: widget.medicine?.takenHistory ?? [],
    );

    Medicine saved;
    if (widget.medicine != null) {
      await repo.updateMedicine(medicine);
      saved = medicine;
    } else {
      saved = await repo.addMedicine(medicine);
    }

    // Schedule Notifications
    await NotificationService.scheduleDailyReminders(saved);

    ref.read(notificationsProvider.notifier).add(
      type: AppNotificationType.medicine,
      title: widget.medicine == null
          ? 'नई दवाई जोड़ी गई / Medicine added'
          : 'दवाई अपडेट की गई / Medicine updated',
      body: '${saved.name} · ${saved.times.length} reminder(s)/day',
    );

    if (mounted) {
      showSuccessSnackBar(context, widget.medicine == null ? 'दवाई जोड़ दी गई' : 'संपादित की गई');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.medicine == null ? 'दवाई जोड़ें / Add Med' : 'संपादित करें / Edit Med'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Medicine Details
            _buildSectionCard(
              title: 'दवाई का विवरण / Med Details',
              colorScheme: colorScheme,
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'दवाई का नाम *',
                      prefixIcon: Icon(Icons.medication_outlined),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dosageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                          decoration: const InputDecoration(
                            labelText: 'खुराक / Dosage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: DropdownMenu<String>(
                          initialSelection: _selectedUnit,
                          label: const Text('इकाई / Unit'),
                          onSelected: (val) => setState(() => _selectedUnit = val!),
                          dropdownMenuEntries: _units.map((u) => DropdownMenuEntry(value: u, label: u)).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: Reminder Times
            _buildSectionCard(
              title: 'अनुस्मारक समय * / Reminders',
              colorScheme: colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._selectedTimes.map((time) => InputChip(
                        label: Text(_formatTime(time)),
                        onDeleted: () => _removeTime(time),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      )),
                      if (_selectedTimes.length < 4)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('जोड़ें'),
                          onPressed: _addTime,
                        ),
                    ],
                  ),
                  if (_selectedTimes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'कम से कम एक समय चुनें',
                        style: TextStyle(color: colorScheme.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 3: Duration
            _buildSectionCard(
              title: 'अवधि / Duration',
              colorScheme: colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3 दिन')),
                      ButtonSegment(value: 7, label: Text('7 दिन')),
                      ButtonSegment(value: 30, label: Text('30 दिन')),
                      ButtonSegment(value: -1, label: Text('हमेशा')),
                    ],
                    selected: {_durationDays},
                    onSelectionChanged: (val) => setState(() => _durationDays = val.first),
                  ),
                  if (_durationDays != -1) ...[
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('प्रारंभ तिथि / Start Date'),
                      subtitle: Text(DateFormat('dd MMMM yyyy').format(_startDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickStartDate,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 4: Settings
            SwitchListTile(
              title: const Text('अभी से शुरू करें / Start Immediately'),
              subtitle: const Text('अनुस्मारक चालू करें'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isFormValid ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(widget.medicine == null ? 'दवाई सहेजें / Save Medicine' : 'अपडेट करें / Update'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required ColorScheme colorScheme, required Widget child}) {
    return Card(
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
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }
}
