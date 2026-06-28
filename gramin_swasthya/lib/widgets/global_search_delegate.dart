import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';

class GlobalSearchAnchor extends StatefulWidget {
  const GlobalSearchAnchor({super.key});

  @override
  State<GlobalSearchAnchor> createState() => _GlobalSearchAnchorState();
}

class _GlobalSearchAnchorState extends State<GlobalSearchAnchor> {
  final SearchController _controller = SearchController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
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
    setState(() {});
  }

  Future<void> _removeRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(term);
    await prefs.setStringList('recent_searches', _recentSearches);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SearchAnchor(
      searchController: _controller,
      isFullScreen: true,
      viewHintText: 'सदस्य, दवाई या रिपोर्ट खोजें...',
      builder: (context, controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => controller.openView(),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        
        if (query.isEmpty) {
          return _buildRecentSearches(context);
        }

        // Parallel Search Queries
        final db = DatabaseHelper.instance;
        final results = await Future.wait([
          db.searchMembers(query),
          db.searchMedicines(query),
          db.searchReports(query),
        ]);

        final members = results[0];
        final medicines = results[1];
        final reports = results[2];

        final List<Widget> suggestionWidgets = [];

        if (members.isNotEmpty) {
          suggestionWidgets.add(_buildSectionHeader(Icons.person, "सदस्य / Members", colorScheme));
          suggestionWidgets.addAll(members.map((m) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
            title: Text(m['name']),
            subtitle: const Text("परिवार सदस्य", style: TextStyle(fontSize: 12)),
            onTap: () {
              _saveSearch(query);
              controller.closeView('');
              context.push('/family');
            },
          )));
        }

        if (medicines.isNotEmpty) {
          suggestionWidgets.add(_buildSectionHeader(Icons.medication, "दवाइयाँ / Medicines", colorScheme));
          suggestionWidgets.addAll(medicines.map((m) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.medication, size: 20)),
            title: Text(m['name']),
            subtitle: Text("${m['dosage']} ${m['unit']}", style: const TextStyle(fontSize: 12)),
            onTap: () {
              _saveSearch(query);
              controller.closeView('');
              context.push('/medicines');
            },
          )));
        }

        if (reports.isNotEmpty) {
          suggestionWidgets.add(_buildSectionHeader(Icons.folder, "रिपोर्ट / Reports", colorScheme));
          suggestionWidgets.addAll(reports.map((r) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.folder, size: 20)),
            title: Text(r['type'] ?? 'Report'),
            subtitle: Text(r['doctor_name'] ?? 'Medical Report', style: const TextStyle(fontSize: 12)),
            onTap: () {
              _saveSearch(query);
              controller.closeView('');
              context.push('/reports');
            },
          )));
        }

        if (suggestionWidgets.isEmpty) {
          return [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text("'$query' के लिए कोई परिणाम नहीं मिला", style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
                  ],
                ),
              ),
            )
          ];
        }

        return suggestionWidgets;
      },
    );
  }

  List<Widget> _buildRecentSearches(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(child: Text("खोजना शुरू करें...", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        )
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("हालिया खोजें / Recent Searches", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      ..._recentSearches.map((term) => ListTile(
        leading: Icon(Icons.history, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}
