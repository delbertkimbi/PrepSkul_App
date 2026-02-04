import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/parent_learners_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'add_child_profile_screen.dart';

/// "My children" screen for parents: list, add, edit, delete linked learners (parent_learners).
class MyChildrenScreen extends StatefulWidget {
  const MyChildrenScreen({Key? key}) : super(key: key);

  @override
  State<MyChildrenScreen> createState() => _MyChildrenScreenState();
}

class _MyChildrenScreenState extends State<MyChildrenScreen> {
  List<Map<String, dynamic>> _learners = [];
  bool _loading = true;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _loadLearners();
  }

  Future<void> _loadLearners() async {
    safeSetState(() => _loading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final parentId = user['userId'] as String?;
      if (parentId == null) return;
      _parentId = parentId;
      
      // First, try to sync any existing child from parent_profiles (for existing users)
      // This is a one-time migration for parents who completed onboarding before sync was added
      try {
        await ParentLearnersService.syncFirstChildFromProfile(parentId);
      } catch (e) {
        // Silently fail - this is just a migration helper
      }
      
      final list = await ParentLearnersService.getLearners(parentId);
      safeSetState(() {
        _learners = list;
        _loading = false;
      });
    } catch (e) {
      safeSetState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load children: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addOrEditChild({Map<String, dynamic>? existing}) async {
    // Navigate to full child profile screen instead of popup
    // This collects all the detailed information needed for tutor matching and algorithms
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddChildProfileScreen(
          existingChild: existing,
          parentId: _parentId!,
        ),
      ),
    );

    // Reload learners after returning from profile screen
    if (result == true) {
      _loadLearners();
    }
  }

  Future<void> _deleteChild(Map<String, dynamic> learner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${learner['name']}?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will only remove them from your list. It won\'t affect past bookings.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.primaryColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || _parentId == null) return;
    try {
      await ParentLearnersService.deleteLearner(learnerId: learner['id'] as String, parentId: _parentId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed')));
      _loadLearners();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My children',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Only show message if there's 0 or 1 child
                if (_learners.length < 2)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Do you have more than 1 child who needs guidance? Add them here so you can select them separately when booking a tutor.',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                Expanded(
                  child: _learners.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.users(), size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No children added yet',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + Add child to add one',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _learners.length,
                          itemBuilder: (context, index) {
                            final learner = _learners[index];
                            final name = learner['name']?.toString() ?? 'Child';
                            final level = [
                              learner['education_level']?.toString(),
                              learner['class_level']?.toString(),
                            ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () => _addOrEditChild(existing: learner),
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                    child: Icon(PhosphorIcons.user(), color: AppTheme.primaryColor),
                                  ),
                                  title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                  subtitle: level.isNotEmpty ? Text(level, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])) : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(PhosphorIcons.pencil(), size: 20, color: AppTheme.primaryColor),
                                        onPressed: () => _addOrEditChild(existing: learner),
                                      ),
                                      IconButton(
                                        icon: Icon(PhosphorIcons.trash(), size: 20, color: Colors.red[400]),
                                        onPressed: () => _deleteChild(learner),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditChild(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add child', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}
