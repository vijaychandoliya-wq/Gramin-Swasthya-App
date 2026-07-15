import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/family_provider.dart';
import '../../providers/health_data_provider.dart';
import '../../services/health_report_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/family_member_selector.dart';

enum HealthType { bp, sugar, weight }

class _ChartPoint {
  final DateTime date;
  final double primary;
  final double? secondary;
  final int? pulse;

  const _ChartPoint({
    required this.date,
    required this.primary,
    this.secondary,
    this.pulse,
  });
}

class _HealthLoadingState extends StatelessWidget {
  const _HealthLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          const Text('स्वास्थ्य डेटा लोड हो रहा है / Loading health data'),
        ],
      ),
    );
  }
}

class _EmptyHealthState extends StatelessWidget {
  final VoidCallback onAddMember;

  const _EmptyHealthState({required this.onAddMember});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 64, color: colors.primary),
            const SizedBox(height: 16),
            const Text('प्रोफ़ाइल जोड़ें / Add a profile',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'स्वास्थ्य रिकॉर्ड शुरू करने के लिए परिवार का सदस्य जोड़ें / Add a family member to start tracking.'),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: onAddMember,
                icon: const Icon(Icons.person_add),
                label: const Text('सदस्य जोड़ें / Add member')),
          ],
        ),
      ),
    );
  }
}

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isGeneratingReport = false;

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

  Future<void> _generateReport() async {
    final member = ref.read(selectedFamilyMemberProvider);
    if (member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a family member first')),
      );
      return;
    }

    setState(() => _isGeneratingReport = true);
    try {
      await HealthReportService.generateAndShare(
        context: context,
        member: member,
        bpReadings: ref.read(bpStreamProvider).valueOrNull ?? const [],
        sugarReadings: ref.read(sugarStreamProvider).valueOrNull ?? const [],
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
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
        actions: [
          IconButton(
            tooltip: 'Share PDF report',
            onPressed: _isGeneratingReport ? null : _generateReport,
            icon: _isGeneratingReport
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          const ProfileAvatarAction(),
          const SizedBox(width: 8),
        ],
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
    ref.watch(selectedFamilyMemberProvider);

    if (familyMembers.isEmpty) {
      return _EmptyHealthState(
          onAddMember: () => context.push('/add-family-member'));
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
          const FamilyMemberSelector(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16)),
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
              loading: () => const _HealthLoadingState(),
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
            loading: () =>
                const SizedBox(height: 120, child: _HealthLoadingState()),
            error: (err, stack) => const SizedBox(),
          ),

          const SizedBox(height: 80), // FAB padding
        ],
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

    final chartPoints = _prepareChartPoints(filtered);
    final double minX =
        chartPoints.first.date.millisecondsSinceEpoch.toDouble();
    final double maxX = chartPoints.last.date.millisecondsSinceEpoch.toDouble();
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
        lineBarsData: _getChartLines(chartPoints),
        extraLinesData: _getExtraLines(),
        rangeAnnotations: _getRangeAnnotations(),
        lineTouchData: _getLineTouchData(chartPoints),
        betweenBarsData: widget.type == HealthType.bp
            ? [
                BetweenBarsData(
                  fromIndex: 0,
                  toIndex: 1,
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                ),
              ]
            : const [],
      ),
    );
  }

  List<_ChartPoint> _prepareChartPoints(List<dynamic> records) {
    final points = records.map<_ChartPoint>((record) {
      if (widget.type == HealthType.bp) {
        return _ChartPoint(
          date: record.date,
          primary: record.systolic.toDouble(),
          secondary: record.diastolic.toDouble(),
          pulse: record.pulse,
        );
      }
      if (widget.type == HealthType.sugar) {
        return _ChartPoint(
            date: record.date, primary: record.glucose.toDouble());
      }
      return _ChartPoint(date: record.date, primary: record.weight.toDouble());
    }).toList();

    // Long views are grouped by week so chart work stays bounded as history grows.
    if (_selectedRange < 90 || points.length <= 45) return points;

    final buckets = <DateTime, List<_ChartPoint>>{};
    for (final point in points) {
      final day = DateTime(point.date.year, point.date.month, point.date.day);
      final weekStart = day.subtract(Duration(days: day.weekday - 1));
      buckets.putIfAbsent(weekStart, () => []).add(point);
    }

    return buckets.entries.map((entry) {
      final values = entry.value;
      final primary =
          values.map((p) => p.primary).reduce((a, b) => a + b) / values.length;
      final secondaryValues = values
          .where((p) => p.secondary != null)
          .map((p) => p.secondary!)
          .toList();
      final secondary = secondaryValues.isEmpty
          ? null
          : secondaryValues.reduce((a, b) => a + b) / secondaryValues.length;
      final pulseValues =
          values.where((p) => p.pulse != null).map((p) => p.pulse!).toList();
      final pulse = pulseValues.isEmpty
          ? null
          : (pulseValues.reduce((a, b) => a + b) / pulseValues.length).round();
      return _ChartPoint(
          date: entry.key,
          primary: primary,
          secondary: secondary,
          pulse: pulse);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double _getChartGridInterval() {
    if (widget.type == HealthType.bp) return 20;
    if (widget.type == HealthType.sugar) return 30;
    return 2;
  }

  List<LineChartBarData> _getChartLines(List<_ChartPoint> filtered) {
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;

    if (widget.type == HealthType.bp) {
      return [
        // Systolic
        LineChartBarData(
          spots: filtered
              .map((r) =>
                  FlSpot(r.date.millisecondsSinceEpoch.toDouble(), r.primary))
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
              .map((r) => FlSpot(
                  r.date.millisecondsSinceEpoch.toDouble(), r.secondary!))
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
              .map((r) =>
                  FlSpot(r.date.millisecondsSinceEpoch.toDouble(), r.primary))
              .toList(),
          isCurved: true,
          color: Colors.blueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ];
    } else {
      final actual = LineChartBarData(
        spots: filtered
            .map((r) =>
                FlSpot(r.date.millisecondsSinceEpoch.toDouble(), r.primary))
            .toList(),
        isCurved: true,
        color: Colors.green,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
      );
      final average = LineChartBarData(
        spots: _movingAverageSpots(filtered),
        isCurved: true,
        color: tertiary,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      );
      return [actual, average];
    }
  }

  List<FlSpot> _movingAverageSpots(List<_ChartPoint> points, {int window = 3}) {
    return points.asMap().entries.map((entry) {
      final start = (entry.key - window + 1).clamp(0, points.length - 1);
      final values = points.sublist(start, entry.key + 1).map((p) => p.primary);
      final average = values.reduce((a, b) => a + b) / values.length;
      return FlSpot(
          entry.value.date.millisecondsSinceEpoch.toDouble(), average);
    }).toList();
  }

  ExtraLinesData _getExtraLines() {
    if (widget.type == HealthType.sugar) {
      return ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 140,
            color: Colors.orangeAccent.withOpacity(0.7),
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
              labelResolver: (line) => '140 high',
            ),
          ),
          HorizontalLine(
            y: 70,
            color: Colors.blueAccent.withOpacity(0.55),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.only(right: 5, top: 5),
              style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
              labelResolver: (line) => '70 low',
            ),
          ),
        ],
      );
    }
    return const ExtraLinesData();
  }

  RangeAnnotations _getRangeAnnotations() {
    if (widget.type != HealthType.sugar) return const RangeAnnotations();
    return RangeAnnotations(
      horizontalRangeAnnotations: [
        HorizontalRangeAnnotation(
          y1: 70,
          y2: 140,
          color: Colors.green.withOpacity(0.08),
        ),
      ],
    );
  }

  LineTouchData _getLineTouchData(List<_ChartPoint> points) {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (spots) {
          return spots.map((spot) {
            final point = points[spot.spotIndex];
            final label = widget.type == HealthType.bp
                ? (spot.barIndex == 0 ? 'Systolic' : 'Diastolic')
                : widget.type == HealthType.sugar
                    ? 'Glucose'
                    : (spot.barIndex == 0 ? 'Weight' : '3-day average');
            final unit = widget.type == HealthType.bp
                ? 'mmHg'
                : widget.type == HealthType.sugar
                    ? 'mg/dL'
                    : 'kg';
            final pulse = widget.type == HealthType.bp && point.pulse != null
                ? '\nPulse: ${point.pulse} bpm'
                : '';
            return LineTooltipItem(
              '${DateFormat('dd MMM').format(point.date)}\n$label: ${spot.y.toStringAsFixed(1)} $unit$pulse',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
    );
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
          final pulse = item.pulse == null ? '—' : '${item.pulse} bpm';
          title = '${item.systolic} / ${item.diastolic} mmHg';
          subtitle =
              '${item.systolic} systolic  •  ${item.diastolic} diastolic  •  $pulse\n${DateFormat('dd MMM yyyy, hh:mm a').format(item.date)}';
          icon = _buildIconBox(Icons.monitor_heart, Colors.redAccent);
        } else if (widget.type == HealthType.sugar) {
          title = '${item.glucose} mg/dL (${item.type})';
          icon = _buildIconBox(Icons.bloodtype, Colors.blueAccent);
        } else {
          final bmi = item.heightCm != null && item.heightCm! > 0
              ? item.weight / ((item.heightCm! / 100) * (item.heightCm! / 100))
              : null;
          title = '${item.weight} kg';
          subtitle = bmi == null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(item.date)
              : 'BMI ${bmi.toStringAsFixed(1)}\n${DateFormat('dd MMM yyyy, hh:mm a').format(item.date)}';
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
