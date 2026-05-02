import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/group_classes/models/group_class_listing.dart';
import 'package:prepskul/features/group_classes/services/group_class_api_service.dart';

class GroupClassesDiscoveryScreen extends StatefulWidget {
  const GroupClassesDiscoveryScreen({super.key});

  @override
  State<GroupClassesDiscoveryScreen> createState() =>
      _GroupClassesDiscoveryScreenState();
}

class _GroupClassesDiscoveryScreenState extends State<GroupClassesDiscoveryScreen> {
  static const Map<String, String> _classTypeLabels = <String, String>{
    '': 'All types',
    'one_time': 'One-time',
    'training': 'Training',
    'bootcamp': 'Bootcamp',
    'workshop': 'Workshop',
  };

  bool _isLoading = true;
  List<GroupClassListing> _classes = <GroupClassListing>[];
  String _classTypeFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await GroupClassApiService.getPublished(
        limit: 50,
        classType: _classTypeFilter.isEmpty ? null : _classTypeFilter,
      );
      if (!mounted) return;
      setState(() {
        _classes = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load group classes: $e')),
      );
    }
  }

  Future<void> _enroll(GroupClassListing listing) async {
    try {
      final result = await GroupClassApiService.enroll(listing.id);
      if (!mounted) return;
      final alreadyEnrolled = result['alreadyEnrolled'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyEnrolled
                ? 'You are already enrolled in this class.'
                : 'Seat reserved. Complete payment to confirm.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrollment failed: $e')),
      );
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(height: 16, width: 180, color: Colors.grey.shade200),
              const SizedBox(height: 10),
              Container(height: 12, width: double.infinity, color: Colors.grey.shade100),
              const SizedBox(height: 6),
              Container(height: 12, width: 220, color: Colors.grey.shade100),
              const SizedBox(height: 12),
              Container(height: 40, width: double.infinity, color: Colors.grey.shade200),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/group_learn.jpeg',
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 220,
          width: 280,
          color: Colors.blueGrey.shade50,
          alignment: Alignment.center,
          child: Icon(Icons.groups_rounded, size: 56, color: Colors.blueGrey.shade300),
        ),
      ),
    );
  }

  Widget _buildListingHeroImage(GroupClassListing listing) {
    final imageUrl = (listing.flyerImageUrl ?? '').trim().isNotEmpty
        ? listing.flyerImageUrl!.trim()
        : (listing.tutorAvatarUrl ?? '').trim();
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Group Classes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _classes.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      const SizedBox(height: 40),
                      Center(child: _buildEmptyImage()),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'No group classes available yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Published sessions from verified tutors will appear here.\nCheck back soon or adjust your filter.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, int index) {
                      if (index == 0) {
                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _classTypeFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by type',
                                ),
                                items: _classTypeLabels.entries
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  setState(() => _classTypeFilter = value);
                                  await _load();
                                },
                              ),
                            ),
                          ],
                        );
                      }

                      final c = _classes[index - 1];
                      final when = DateFormat('EEE, d MMM - HH:mm').format(c.startsAt.toLocal());
                      final typeLabel = _classTypeLabels[c.classType] ?? c.classType;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildListingHeroImage(c),
                            if (((c.flyerImageUrl ?? '').trim().isNotEmpty ||
                                (c.tutorAvatarUrl ?? '').trim().isNotEmpty))
                              const SizedBox(height: 10),
                            Text(
                              c.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                if ((c.subject ?? '').trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      c.subject!.trim(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            if ((c.learningFocus ?? '').trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                c.learningFocus!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              when,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${c.currencyCode} ${c.pricePerSeat.toStringAsFixed(0)} per seat - Capacity ${c.capacity}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _enroll(c),
                                child: const Text('Reserve Seat'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

