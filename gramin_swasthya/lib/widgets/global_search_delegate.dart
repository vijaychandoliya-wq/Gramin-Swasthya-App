import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../../providers/family_provider.dart';

/// Global "search anything" anchor (Material 3 SearchAnchor). Searches members,
/// medicines, reports, and BP / sugar / weight readings in parallel, and taps
/// deep-link to the right screen with the matching family member selected.
class GlobalSearchAnchor extends ConsumerStatefulWidget {
  const GlobalSearchAnchor({super.key});

  @override
  ConsumerState<GlobalSearchAnchor> createState() => _GlobalSearchAnchorState();
}

class _GlobalSearchAnchorState extends ConsumerState<GlobalSearchAnchor> {
  final SearchController _controller = SearchController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 5) _recentSearches.removeLast();
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  Future<void> _removeRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(term);
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  String _memberName(Object? memberId) {
    final id = memberId?.toString();
    final matches = ref.read(familyProvider).where((e) => e.id == id);
    return matches.isNotEmpty ? matches.first.name : 'सदस्य';
  }

  String _fmtDate(Object? iso) {
    final s = iso?.toString();
    if (s == null || s.isEmpty) return '';
    final d = DateTime.tryParse(s);
    return d == null ? '' : DateFormat('dd MMM').format(d);
  }

  /// Save the query, select the owning member (so per-member screens show the
  /// right data), close the search view, then navigate.
  void _openResult(SearchController controller, String query, String route,
      {Object? memberId}) {
    _saveSearch(query);
    if (memberId != null) {
      final id = memberId.toString();
      final matches = ref.read(familyProvider).where((e) => e.id == id);
      if (matches.isNotEmpty) {
        ref.read(selectedFamilyMemberProvider.notifier).state = matches.first;
      }
    }
    controller.closeView('');
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SearchAnchor(
      searchController: _controller,
      isFullScreen: true,
      viewHintText: 'कुछ भी खोजें / Search anything...',
      builder: (context, controller) {
        return IconButton(
          tooltip: 'खोजें / Search',
          icon: const Icon(Icons.search),
          onPressed: () => controller.openView(),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        if (query.isEmpty) return _buildRecentSearches(context);

        final db = DatabaseHelper.instance;
        final results = await Future.wait([
          db.searchMembers(query), // 0
          db.searchMedicines(query), // 1
          db.searchReports(query), // 2
          db.searchBpReadings(query), // 3
          db.searchSugarReadings(query), // 4
          db.searchWeightEntries(query), // 5
        ]);

        final widgets = <Widget>[];

        Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) =>
            ListTile(
              leading: CircleAvatar(child: Icon(icon, size: 20)),
              title: Text(title),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              onTap: onTap,
            );

        if (results[0].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.person, 'सदस्य / Members', colorScheme));
          for (final m in results[0]) {
            widgets.add(tile(
              Icons.person,
              m['name']?.toString() ?? '',
              [m['blood_group'], m['gender']]
                  .where((e) => e != null && '$e'.isNotEmpty)
                  .join(' · '),
              () => _openResult(controller, query, '/family', memberId: m['id']),
            ));
          }
        }

        if (results[1].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.medication, 'दवाइयाँ / Medicines', colorScheme));
          for (final m in results[1]) {
            widgets.add(tile(
              Icons.medication,
              m['name']?.toString() ?? '',
              '${m['dosage'] ?? ''} ${m['unit'] ?? ''} · ${_memberName(m['member_id'])}',
              () => _openResult(controller, query, '/medicines', memberId: m['member_id']),
            ));
          }
        }

        if (results[2].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.folder, 'रिपोर्ट / Reports', colorScheme));
          for (final r in results[2]) {
            widgets.add(tile(
              Icons.folder,
              r['type']?.toString() ?? 'Report',
              '${r['doctor_name'] ?? 'Medical Report'} · ${_fmtDate(r['report_date'])}',
              () => _openResult(controller, query, '/reports', memberId: r['member_id']),
            ));
          }
        }

        if (results[3].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.monitor_heart, 'रक्तचाप / BP', colorScheme));
          for (final b in results[3]) {
            widgets.add(tile(
              Icons.monitor_heart,
              '${b['systolic']}/${b['diastolic']} mmHg',
              '${_memberName(b['member_id'])} · ${_fmtDate(b['recorded_at'])}',
              () => _openResult(controller, query, '/health', memberId: b['member_id']),
            ));
          }
        }

        if (results[4].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.water_drop, 'शुगर / Sugar', colorScheme));
          for (final s in results[4]) {
            widgets.add(tile(
              Icons.water_drop,
              '${s['value']} mg/dL',
              '${s['type'] ?? ''} · ${_memberName(s['member_id'])} · ${_fmtDate(s['recorded_at'])}',
              () => _openResult(controller, query, '/health', memberId: s['member_id']),
            ));
          }
        }

        if (results[5].isNotEmpty) {
          widgets.add(_buildSectionHeader(Icons.monitor_weight, 'वजन / Weight', colorScheme));
          for (final w in results[5]) {
            widgets.add(tile(
              Icons.monitor_weight,
              '${w['weight_kg']} kg',
              '${_memberName(w['member_id'])} · ${_fmtDate(w['recorded_at'])}',
              () => _openResult(controller, query, '/health', memberId: w['member_id']),
            ));
          }
        }

        if (widgets.isEmpty) {
          return [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text("'$query' के लिए कोई परिणाम नहीं / No results",
                        style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
                  ],
                ),
              ),
            )
          ];
        }

        return widgets;
      },
    );
  }

  List<Widget> _buildRecentSearches(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_recentSearches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text("खोजना शुरू करें...",
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        )
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("हालिया खोजें / Recent Searches",
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      ),
      ..._recentSearches.map((term) => ListTile(
            leading: Icon(Icons.history, size: 20, color: colorScheme.onSurfaceVariant),
            title: Text(term),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => _removeRecentSearch(term),
            ),
            onTap: () => _controller.text = term,
          )),
    ];
  }

  Widget _buildSectionHeader(IconData icon, String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}
