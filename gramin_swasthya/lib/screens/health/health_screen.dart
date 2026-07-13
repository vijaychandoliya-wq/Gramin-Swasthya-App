import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/family_provider.dart';
import '../../providers/health_data_provider.dart';
import '../../widgets/profile_avatar.dart';

enum HealthType { bp, sugar, weight }

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFabPressed() {
    switch (_tabController.index) {
      case 0:
        context.push('/add-bp');
        break;
      case 1:
        context.push('/add-sugar');
        break;
      case 2:
        context.push('/add-weight');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const LocalizedText('स्वास्थ्य डेटा / Health Data'),
        actions: const [ProfileAvatarAction(), SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.onPrimaryContainer,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          splashBorderRadius: BorderRadius.circular(50),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(child: FittedBox(child: LocalizedText("BP", maxLines: 1))),
            Tab(child: FittedBox(child: LocalizedText("Sugar", maxLines: 1))),
            Tab(child: FittedBox(child: LocalizedText("Weight", maxLines: 1))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HealthTabContent(type: HealthType.bp),
          _HealthTabContent(type: HealthType.sugar),
          _HealthTabContent(type: HealthType.weight),
        ],
      ),
    );
  }
}

class _HealthTabContent extends ConsumerStatefulWidget {
  final HealthType type;
  const _HealthTabContent({required this.type});

  @override
  ConsumerState<_HealthTabContent> createState() => _HealthTabContentState();
}

class _HealthTabContentState extends ConsumerState<_HealthTabContent> {
  int _selectedRange = 30; // 7, 30, 90 days

  @override
  Widget build(BuildContext context) {
    final familyMembers = ref.watch(familyProvider);
    final selectedMember = ref.watch(selectedFamilyMemberProvider) ??
        (familyMembers.isNotEmpty ? familyMembers.first : null);

    if (selectedMember == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determine stream
    AsyncValue<dynamic> streamValue;
    switch (widget.type) {
      case HealthType.bp:
        streamValue = ref.watch(bpStreamProvider);
        break;
      case HealthType.sugar:
        streamValue = ref.watch(sugarStreamProvider);
        break;
      case HealthType.weight:
        streamValue = ref.watch(weightStreamProvider);
        break;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips Row
          _buildFamilySelectorRow(familyMembers, selectedMember),
          const SizedBox(height: 16),

          // Segmented Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: LocalizedText('7 दिन')),
                ButtonSegment(value: 30, label: LocalizedText('30 दिन')),
                ButtonSegment(value: 90, label: LocalizedText('90 दिन')),
              ],
              selected: <int>{_selectedRange},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedRange = newSelection.first;
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          // Chart Render
          Container(
            height: 220,
            padding:
                const EdgeInsets.only(right: 24, left: 16, top: 24, bottom: 0),
            child: streamValue.when(
              data: (data) => _buildChart(data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: LocalizedText('Error: $err')),
            ),
          ),

          const SizedBox(height: 32),

          // History List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LocalizedText(
              'इतिहास / History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 32),

          streamValue.when(
            data: (data) => _buildHistoryList(data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const SizedBox(),
          ),

          const SizedBox(height: 80), // FAB padding
        ],
      ),
    );
  }

  Widget _buildFamilySelectorRow(
      List<FamilyMember> familyMembers, FamilyMember currentMember) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: familyMembers.map((member) {
            final isSelected = member.id == currentMember.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isSelected,
                label: LocalizedText(member.name.split(' ').first),
                avatar: isSelected
                    ? CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        child: LocalizedText(
                          member.name[0].toUpperCase(),
                          style: TextStyle(
                              color: colorScheme.onPrimary, fontSize: 12),
                        ),
                      )
                    : null,
                showCheckmark: false,
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primaryContainer,
                onSelected: (bool selected) {
                  if (selected) {
                    ref.read(selectedFamilyMemberProvider.notifier).state =
                        member;
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ------- CHART LOGIC ------- //

  Widget _buildChart(List<dynamic> data) {
    if (data.isEmpty) {
      return Center(
        child: LocalizedText(
          'कोई डेटा नहीं / No Data',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedRange));
    final filtered = data
        .where((r) => r.date.isAfter(cutoff) || r.date.isAtSameMomentAs(cutoff))
        .toList();

    // Sort chronological for chart
    filtered.sort((a, b) => a.date.compareTo(b.date));

    if (filtered.isEmpty) {
      return const Center(
          child: LocalizedText('इस सीमा में कोई डेटा नहीं / No data in range'));
    }

    final double minX = filtered.first.date.millisecondsSinceEpoch.toDouble();
    final double maxX = filtered.last.date.millisecondsSinceEpoch.toDouble();
    final double interval =
        ((maxX - minX) / 4) <= 0 ? 86400000.0 : ((maxX - minX) / 3);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getChartGridInterval(),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == minX || value == maxX) return const SizedBox();
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: LocalizedText(DateFormat('MMM dd').format(date),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: LocalizedText(value.toInt().toString(),
                    style: const TextStyle(fontSize: 10)),
              ),
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: _getChartLines(filtered),
        extraLinesData: _getExtraLines(),
      ),
    );
  }

  double _getChartGridInterval() {
    if (widget.type == HealthType.bp) return 20;
    if (widget.type == HealthType.sugar) return 30;
    return 2;
  }

  List<LineChartBarData> _getChartLines(List<dynamic> filtered) {
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;

    if (widget.type == HealthType.bp) {
      return [
        // Systolic
        LineChartBarData(
          spots: filtered
              .map((r) => FlSpot(r.date.millisecondsSinceEpoch.toDouble(),
                  r.systolic.toDouble()))
              .toList(),
          isCurved: true,
          color: primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
        // Diastolic
        LineChartBarData(
          spots: filtered
              .map((r) => FlSpot(r.date.millisecondsSinceEpoch.toDouble(),
                  r.diastolic.toDouble()))
              .toList(),
          isCurved: true,
          color: tertiary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ];
    } else if (widget.type == HealthType.sugar) {
      return [
        LineChartBarData(
          spots: filtered
              .map((r) => FlSpot(r.date.millisecondsSinceEpoch.toDouble(),
                  r.glucose.toDouble()))
              .toList(),
          isCurved: true,
          color: Colors.blueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ];
    } else {
      return [
        LineChartBarData(
          spots: filtered
              .map((r) => FlSpot(r.date.millisecondsSinceEpoch.toDouble(),
                  r.weight.toDouble()))
              .toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ];
    }
  }

  ExtraLinesData _getExtraLines() {
    if (widget.type == HealthType.sugar) {
      return ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 130, // threshold
            color: Colors.redAccent.withOpacity(0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              labelResolver: (line) => 'Threshold',
            ),
          )
        ],
      );
    }
    return const ExtraLinesData();
  }

  // ------- HISTORY LOGIC ------- //

  Widget _buildHistoryList(List<dynamic> data) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: LocalizedText('कोई इतिहास नहीं / No History'),
      );
    }

    final repo = ref.read(healthRepoProvider);

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];

        String title = '';
        String subtitle = DateFormat('dd MMM yyyy, hh:mm a').format(item.date);
        Widget icon;

        if (widget.type == HealthType.bp) {
          title = '${item.systolic} / ${item.diastolic} mmHg';
          icon = _buildIconBox(Icons.monitor_heart, Colors.redAccent);
        } else if (widget.type == HealthType.sugar) {
          title = '${item.glucose} mg/dL (${item.type})';
          icon = _buildIconBox(Icons.bloodtype, Colors.blueAccent);
        } else {
          title = '${item.weight} kg';
          icon = _buildIconBox(Icons.scale, Colors.green);
        }

        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
          ),
          onDismissed: (direction) {
            // Delete from repo
            if (widget.type == HealthType.bp) {
              repo.deleteBp(item.id);
            } else if (widget.type == HealthType.sugar) {
              repo.deleteSugar(item.id);
            } else if (widget.type == HealthType.weight) {
              repo.deleteWeight(item.id);
            }

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const LocalizedText(
                    'रिकॉर्ड हटा दिया गया / Record deleted'),
                action: SnackBarAction(
                  label: AppLanguage.text('Undo'),
                  onPressed: () {
                    // Restore item
                    if (widget.type == HealthType.bp) {
                      repo.addBp(item);
                    } else if (widget.type == HealthType.sugar) {
                      repo.addSugar(item);
                    } else if (widget.type == HealthType.weight) {
                      repo.addWeight(item);
                    }
                  },
                ),
              ),
            );
          },
          child: ListTile(
            leading: icon,
            title: LocalizedText(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: LocalizedText(subtitle),
          ),
        );
      },
    );
  }

  Widget _buildIconBox(IconData iconData, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color),
    );
  }
}
