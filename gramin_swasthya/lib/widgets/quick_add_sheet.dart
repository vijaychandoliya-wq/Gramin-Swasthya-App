import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/health_data_provider.dart';

enum SugarType { fasting, postMeal, random }

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _sugarController = TextEditingController();
  final _weightController = TextEditingController();

  SugarType _sugarType = SugarType.random;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _sugarController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;

    final index = _tabController.index;
    final repo = ref.read(healthRepoProvider);
    final now = DateTime.now();

    setState(() => _saving = true);

    try {
      if (index == 0) {
        // BP
        final sys = int.tryParse(_systolicController.text);
        final dia = int.tryParse(_diastolicController.text);
        if (sys == null || dia == null || sys < 50 || sys > 250 || dia < 40 || dia > 150) {
          _showError('कृपया सही BP दर्ज करें / Enter valid BP');
          return;
        }
        await repo.addBp(BpRecord(
          id: const Uuid().v4(),
          systolic: sys,
          diastolic: dia,
          date: now,
        ));
      } else if (index == 1) {
        // Sugar
        final glucose = double.tryParse(_sugarController.text);
        if (glucose == null || glucose < 20 || glucose > 600) {
          _showError('कृपया सही शुगर दर्ज करें / Enter valid sugar');
          return;
        }
        String typeStr;
        switch (_sugarType) {
          case SugarType.fasting: typeStr = 'Fasting'; break;
          case SugarType.postMeal: typeStr = 'Post-meal'; break;
          case SugarType.random: typeStr = 'Random'; break;
        }
        await repo.addSugar(SugarRecord(
          id: const Uuid().v4(),
          glucose: glucose,
          type: typeStr,
          date: now,
        ));
      } else if (index == 2) {
        // Weight
        final weight = double.tryParse(_weightController.text);
        if (weight == null || weight < 20 || weight > 300) {
          _showError('कृपया सही वजन दर्ज करें / Enter valid weight');
          return;
        }
        await repo.addWeight(WeightRecord(
          id: const Uuid().v4(),
          weight: weight,
          date: now,
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('सहेजने में त्रुटि / Error saving');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Center(
            child: Container(
              height: 4,
              width: 32,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 24, right: 24),
            child: Text(
              'त्वरित जोड़ें / Quick Add',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: colorScheme.onPrimaryContainer,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicator: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(50),
            ),
            splashBorderRadius: BorderRadius.circular(50),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: "BP"),
              Tab(text: "शुगर"),
              Tab(text: "वजन"),
            ],
          ),

          // Tab Views
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBpTab(),
                  _buildSugarTab(),
                  _buildWeightTab(),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: max(24, 16), left: 24, right: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('रद्द'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _onSave,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('सहेजें (Save)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _systolicController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'Systolic',
              suffixText: 'mmHg',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _diastolicController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'Diastolic',
              suffixText: 'mmHg',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSugarTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SegmentedButton<SugarType>(
            segments: const [
              ButtonSegment(value: SugarType.fasting, label: Text('Fasting')),
              ButtonSegment(value: SugarType.random, label: Text('Random')),
              ButtonSegment(value: SugarType.postMeal, label: Text('Post-meal')),
            ],
            selected: <SugarType>{_sugarType},
            onSelectionChanged: (newSelection) {
              setState(() {
                _sugarType = newSelection.first;
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sugarController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'Sugar Level',
              suffixText: 'mg/dL',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTab() {
    return Center(
      child: TextField(
        controller: _weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        maxLength: 5,
        decoration: const InputDecoration(
          labelText: 'वजन (Weight)',
          suffixText: 'kg',
          border: OutlineInputBorder(),
          counterText: '',
          floatingLabelAlignment: FloatingLabelAlignment.center,
        ),
      ),
    );
  }
}
