import 'package:flutter/material.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import '../screens/mate_local_lesson_screen.dart';
import '../services/skulmate_tutor_voice_service.dart';

class MateAccessBar extends StatelessWidget {
  const MateAccessBar({super.key, this.unavailable = false});
  final bool unavailable;
  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) => snapshot.data != false && !unavailable
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.data == false)
                    Text(
                      fr
                          ? 'Hors ligne : le tutorat en direct attendra. Tu peux continuer ici.'
                          : 'Offline: live tutoring needs a connection. You can keep learning here.',
                      style: LearnerDesign.body(14),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final counting in [false, true])
                        ActionChip(
                          avatar: PrepSkulIcon(
                            counting
                                ? PrepSkulGlyph.practice
                                : PrepSkulGlyph.learn,
                            size: 23,
                          ),
                          label: Text(
                            counting
                                ? (fr
                                      ? 'Apprendre à compter'
                                      : 'Practise counting')
                                : (fr
                                      ? 'Explorer les forces'
                                      : 'Explore forces'),
                          ),
                          onPressed: () async {
                            await SkulMateTutorVoiceService.instance
                                .endSession();
                            if (!context.mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MateLocalLessonScreen(counting: counting),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
