import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/group_classes/screens/create_group_class_screen.dart';
import 'package:prepskul/features/group_classes/models/group_class_listing.dart';
import 'package:prepskul/features/group_classes/services/group_class_api_service.dart';

class TutorGroupClassesScreen extends StatefulWidget {
  const TutorGroupClassesScreen({super.key});

  @override
  State<TutorGroupClassesScreen> createState() => _TutorGroupClassesScreenState();
}

class _TutorGroupClassesScreenState extends State<TutorGroupClassesScreen> {
  static const Map<String, String> _classTypeLabels = <String, String>{
    'one_time': 'One-time',
    'training': 'Training',
    'bootcamp': 'Bootcamp',
    'workshop': 'Workshop',
  };

  bool _isLoading = true;
  List<GroupClassListing> _items = <GroupClassListing>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await GroupClassApiService.getMine(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load your classes: $e')),
      );
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
          width: double.infinity,
          color: Colors.blueGrey.shade50,
          alignment: Alignment.center,
          child: Icon(Icons.school_rounded, size: 56, color: Colors.blueGrey.shade300),
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
          'My Group Classes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<GroupClassListing>(
            MaterialPageRoute(builder: (_) => const CreateGroupClassScreen()),
          );
          if (!mounted || result == null) return;
          await _load();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.status == 'published'
                    ? 'Class published.'
                    : 'Class saved as draft.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      const SizedBox(height: 40),
                      Center(child: _buildEmptyImage()),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'No group classes created yet',
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
                          'Create your first class to start receiving paid learner enrollments.',
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
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, int index) {
                      final item = _items[index];
                      final when = DateFormat('EEE, d MMM - HH:mm').format(item.startsAt.toLocal());
                      final typeLabel = _classTypeLabels[item.classType] ?? item.classType;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildListingHeroImage(item),
                            if (((item.flyerImageUrl ?? '').trim().isNotEmpty ||
                                (item.tutorAvatarUrl ?? '').trim().isNotEmpty))
                              const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.status == 'published'
                                        ? Colors.green.withOpacity(0.14)
                                        : Colors.orange.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item.status.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: item.status == 'published' ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
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
                                if ((item.approvalStatus).trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (item.approvalStatus == 'approved'
                                              ? Colors.green
                                              : item.approvalStatus == 'rejected'
                                                  ? Colors.red
                                                  : item.approvalStatus == 'changes_requested'
                                                      ? Colors.orange
                                                      : Colors.grey)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      item.approvalStatus.replaceAll('_', ' ').toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if ((item.learningFocus ?? '').trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                item.learningFocus!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '$when  -  ${item.currencyCode} ${item.pricePerSeat.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                            ),
                            if (item.status != 'published') ...<Widget>[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await GroupClassApiService.publish(item.id);
                                      if (!mounted) return;
                                      await _load();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Class published.')),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Publish failed: $e')),
                                      );
                                    }
                                  },
                                  child: const Text('Publish'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

