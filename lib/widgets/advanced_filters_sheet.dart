import 'package:flutter/material.dart';
import '../models/conversational_search_session.dart';
import '../models/search_intent.dart';
import '../models/search_query.dart';

/// Modal bottom sheet providing advanced manual filter configuration.
///
/// Keeps manual selections fully in sync with the active [SearchConversationSession].
class AdvancedFiltersSheet extends StatefulWidget {
  final SearchConversationSession session;
  final ValueChanged<SearchQuery> onApply;

  const AdvancedFiltersSheet({
    super.key,
    required this.session,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required SearchConversationSession session,
    required ValueChanged<SearchQuery> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AdvancedFiltersSheet(
        session: session,
        onApply: onApply,
      ),
    );
  }

  @override
  State<AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<AdvancedFiltersSheet> {
  late SearchIntent _intent;
  late final TextEditingController _rallyController;
  late final TextEditingController _driverController;
  late final TextEditingController _cityController;
  late List<String> _selectedCountries;
  late List<int> _selectedYears;
  late List<String> _selectedActionTypes;
  late MatchMode _driverMatchMode;

  final List<String> _allActionOptions = [
    'jump',
    'drift',
    'crash',
    'spin',
    'donut',
    'hairpin',
    'water splash',
    'start line',
    'near miss',
    'mechanical failure',
    'offroad',
    'stuck',
  ];

  final List<Map<String, String>> _countryOptions = [
    {'label': 'Ireland (IE)', 'value': 'Ireland'},
    {'label': 'United Kingdom (UK)', 'value': 'United Kingdom'},
    {'label': 'Portugal (PT)', 'value': 'Portugal'},
    {'label': 'Austria (AT)', 'value': 'Austria'},
    {'label': 'France (FR)', 'value': 'France'},
    {'label': 'Norway (NO)', 'value': 'Norway'},
    {'label': 'Poland (PL)', 'value': 'Poland'},
    {'label': 'Belgium (BE)', 'value': 'Belgium'},
    {'label': 'Spain (ES)', 'value': 'Spain'},
    {'label': 'Italy (IT)', 'value': 'Italy'},
    {'label': 'Latvia (LV)', 'value': 'Latvia'},
    {'label': 'Czech Republic (CZ)', 'value': 'Czech Republic'},
    {'label': 'Germany (DE)', 'value': 'Germany'},
    {'label': 'Kenya (KE)', 'value': 'Kenya'},
    {'label': 'Croatia (HR)', 'value': 'Croatia'},
    {'label': 'Netherlands (NL)', 'value': 'Netherlands'},
    {'label': 'New Zealand (NZ)', 'value': 'New Zealand'},
    {'label': 'Lithuania (LT)', 'value': 'Lithuania'},
    {'label': 'Slovakia (SK)', 'value': 'Slovakia'},
    {'label': 'Qatar (QA)', 'value': 'Qatar'},
    {'label': 'Pakistan (PK)', 'value': 'Pakistan'},
    {'label': 'Barbados (BB)', 'value': 'Barbados'},
    {'label': 'Sweden (SE)', 'value': 'Sweden'},
    {'label': 'Finland (FI)', 'value': 'Finland'},
    {'label': 'Estonia (EE)', 'value': 'Estonia'},
  ];

  final List<int> _yearOptions = [2026, 2025, 2024, 2023, 2022, 2021, 2020];

  @override
  void initState() {
    super.initState();
    final q = widget.session.activeQuery;
    _intent = q.intent;
    _rallyController = TextEditingController(text: q.targetRallyName ?? '');
    _driverController = TextEditingController(text: q.driverNames.join(', '));
    _cityController = TextEditingController(text: q.cities.join(', '));
    _selectedCountries = List<String>.from(q.countries);
    _selectedYears = List<int>.from(q.years);
    _selectedActionTypes = List<String>.from(q.actionTypes);
    _driverMatchMode = q.driverMatchMode;
  }

  @override
  void dispose() {
    _rallyController.dispose();
    _driverController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _handleApply() {
    final rawRally = _rallyController.text.trim();
    final rawDriver = _driverController.text.trim();
    final rawCity = _cityController.text.trim();

    final driverList = rawDriver.isNotEmpty
        ? rawDriver.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final cityList = rawCity.isNotEmpty
        ? rawCity.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final updated = widget.session.activeQuery.copyWith(
      intent: _intent,
      rallyNames: rawRally.isNotEmpty ? [rawRally] : [],
      driverNames: driverList,
      cities: cityList,
      countries: _selectedCountries,
      years: _selectedYears,
      actionTypes: _selectedActionTypes,
      driverMatchMode: _driverMatchMode,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  void _handleReset() {
    setState(() {
      _intent = SearchIntent.searchRallies;
      _rallyController.clear();
      _driverController.clear();
      _cityController.clear();
      _selectedCountries.clear();
      _selectedYears.clear();
      _selectedActionTypes.clear();
      _driverMatchMode = MatchMode.any;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Advanced Filters',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _handleReset,
                        child: const Text('Reset'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),

              // Scrollable Filter Sections
              Expanded(
                child: ListView(
                  children: [
                    // Search Intent
                    const Text('Search Intent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<SearchIntent>(
                      value: _intent,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: SearchIntent.values.map((i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(i.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _intent = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Target Rally Field
                    const Text('Rally Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rallyController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Moonraker, Donegal, Trackrod...',
                        prefixIcon: const Icon(Icons.flag_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Driver Name Field
                    const Text('Driver Names (comma-separated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _driverController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Josh Moffett, Sam Moffett...',
                        prefixIcon: const Icon(Icons.person_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Countries (Multi-select Chips)
                    const Text('Countries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _countryOptions.map((c) {
                        final val = c['value']!;
                        final isSelected = _selectedCountries.contains(val);
                        return FilterChip(
                          label: Text(c['label']!, style: const TextStyle(fontSize: 11.5)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCountries.add(val);
                              } else {
                                _selectedCountries.remove(val);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Years (Multi-select Chips)
                    const Text('Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _yearOptions.map((yr) {
                        final isSelected = _selectedYears.contains(yr);
                        return FilterChip(
                          label: Text('$yr', style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedYears.add(yr);
                              } else {
                                _selectedYears.remove(yr);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Action Types (Multi-select Chips)
                    const Text('Action Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _allActionOptions.map((act) {
                        final isSelected = _selectedActionTypes.contains(act);
                        final cap = act[0].toUpperCase() + act.substring(1);
                        return FilterChip(
                          label: Text(cap, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedActionTypes.add(act);
                              } else {
                                _selectedActionTypes.remove(act);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // City Field
                    const Text('City / Locality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Letterkenny, Fafe...',
                        prefixIcon: const Icon(Icons.location_city_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Apply Button
              FilledButton.icon(
                onPressed: _handleApply,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
