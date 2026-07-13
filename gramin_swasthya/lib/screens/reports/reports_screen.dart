import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/family_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/profile_avatar.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isGrid = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(filteredReportsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLanguage.text('सर्च करें... / Search...'),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              )
            : const LocalizedText('रिपोर्ट / Reports'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(_isGrid ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          const ProfileAvatarAction(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/reports/add'),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: reportsAsync.when(
                data: (reports) {
                  // Apply search filter locally
                  final filteredBySearch = reports.where((r) {
                    final query = _searchController.text.toLowerCase();
                    return r.doctorName.toLowerCase().contains(query) ||
                        r.type.toLowerCase().contains(query);
                  }).toList();

                  if (filteredBySearch.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _isGrid
                      ? _buildGridView(filteredBySearch)
                      : _buildListView(filteredBySearch);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: LocalizedText('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final familyMembers = ref.watch(familyProvider);
    final selectedMember = ref.watch(selectedFamilyMemberProvider) ??
        (familyMembers.isNotEmpty ? familyMembers.first : null);
    final activeType = ref.watch(activeReportTypeFilterProvider);
    final reportTypes = ["All", "Prescription", "Lab Report", "X-Ray", "Other"];

    return Column(
      children: [
        // Family Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: familyMembers.map((member) {
              final isSelected = member.id == selectedMember?.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: LocalizedText(member.name.split(' ').first),
                  onSelected: (val) {
                    if (val) {
                      ref.read(selectedFamilyMemberProvider.notifier).state =
                          member;
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // Type Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: reportTypes.map((type) {
              final isSelected = type == activeType;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: LocalizedText(type),
                  onSelected: (val) {
                    if (val) {
                      ref.read(activeReportTypeFilterProvider.notifier).state =
                          type;
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildGridView(List<MedicalReport> reports) {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          child: InkWell(
            onTap: () =>
                context.push('/reports/view/${report.id}', extra: report),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'report_${report.id}',
                        child: report.imagePath != null
                            ? report.imagePath!.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: report.imagePath!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : Image.file(
                                    File(report.imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(Icons.image_outlined,
                                          size: 48),
                                    ),
                                  )
                            : Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.description_outlined,
                                    size: 48),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(report.type,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          LocalizedText(
                              DateFormat('dd MMM yyyy').format(report.date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Chip(
                    label: LocalizedText(report.type.split(' ').first,
                        style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<MedicalReport> reports) {
    return ListView.builder(
      key: const ValueKey('list'),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return ListTile(
          leading: Hero(
            tag: 'report_${report.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_outlined),
              ),
            ),
          ),
          title: LocalizedText(report.type,
              style: Theme.of(context).textTheme.titleSmall),
          subtitle: LocalizedText(
              '${report.doctorName} • ${DateFormat('dd MMM yyyy').format(report.date)}',
              style: Theme.of(context).textTheme.bodySmall),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.push('/reports/view/${report.id}', extra: report),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
          const SizedBox(height: 16),
          const LocalizedText('कोई रिपोर्ट नहीं / No Reports'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/reports/add'),
            child: const LocalizedText('जोड़ें / Add'),
          ),
        ],
      ),
    );
  }
}
