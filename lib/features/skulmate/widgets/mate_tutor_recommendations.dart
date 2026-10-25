import 'package:flutter/material.dart';
import '../../../core/services/tutor_service.dart';
import '../../discovery/screens/tutor_detail_screen.dart';

/// Uses real directory entries, never model-invented names or availability.
class MateTutorRecommendations extends StatefulWidget {
  final String subject;
  const MateTutorRecommendations({super.key, required this.subject});
  @override
  State<MateTutorRecommendations> createState() =>
      _MateTutorRecommendationsState();
}

class _MateTutorRecommendationsState extends State<MateTutorRecommendations> {
  late Future<List<Map<String, dynamic>>> _tutors;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _tutors = TutorService.fetchTutors(
      subject: widget.subject,
      limit: 3,
    ).timeout(const Duration(seconds: 15));
  }

  @override
  void didUpdateWidget(covariant MateTutorRecommendations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject) _load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _tutors,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError)
        return TextButton(
          onPressed: () => setState(_load),
          child: const Text('Retry tutor suggestions'),
        );
      final tutors = snapshot.data ?? [];
      if (tutors.isEmpty)
        return Text(
          'No tutor matches for ${widget.subject} yet. Try the tutor directory.',
        );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra help with ${widget.subject}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'From your learning subjects. Open a profile to check fit and availability.',
          ),
          const SizedBox(height: 8),
          for (final tutor in tutors)
            Card(
              child: ListTile(
                title: Text('${tutor['full_name'] ?? 'Tutor'}'),
                subtitle: Text(widget.subject),
                trailing: const Text('View'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TutorDetailScreen(tutor: tutor),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
