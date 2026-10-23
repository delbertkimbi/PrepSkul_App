import 'package:flutter/material.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import '../screens/mate_learning_progress_screen.dart';
import '../services/skulmate_session_cache.dart';

class SkulMateHomeTopBar extends StatelessWidget {
  final String? childId;
  final String? activeSessionId;
  final ValueChanged<String>? onSelectSession;
  final VoidCallback? onNewSession;
  final VoidCallback? onBack;
  const SkulMateHomeTopBar({
    super.key,
    this.childId,
    this.activeSessionId,
    this.onSelectSession,
    this.onNewSession,
    this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          if (onBack != null) BackButton(onPressed: onBack),
          const SizedBox(width: 4),
          Text('Mate', style: LearnerDesign.title(24)),
          const Spacer(),
          IconButton(
            tooltip: fr ? 'Ma série d’apprentissage' : 'Learning streak',
            icon: const PrepSkulIcon(PrepSkulGlyph.streak),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MateLearningProgressScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: fr ? 'Menu des séances' : 'Session menu',
            icon: const Icon(Icons.menu_rounded, color: LearnerDesign.ink),
            onPressed: () => _openSessions(context, fr),
          ),
        ],
      ),
    );
  }

  void _openSessions(BuildContext context, bool fr) {
    final sessions = SkulMateSessionCache.savedSessions();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: fr ? 'Fermer les séances' : 'Close sessions',
      barrierColor: Colors.black38,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
      pageBuilder: (drawerContext, _, __) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(0, 360).toDouble(),
          height: double.infinity,
          child: Material(
            color: LearnerDesign.canvas,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fr ? 'Mes séances' : 'Your sessions',
                            style: LearnerDesign.title(24),
                          ),
                        ),
                        IconButton(
                          tooltip: fr ? 'Fermer' : 'Close',
                          onPressed: () => Navigator.pop(drawerContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: LearnerDesign.ink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: const PrepSkulIcon(PrepSkulGlyph.learn),
                        label: Text(fr ? 'Nouvelle séance' : 'New session'),
                        onPressed: () {
                          Navigator.pop(drawerContext);
                          onNewSession?.call();
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fr ? 'Séances précédentes' : 'Past sessions',
                            style: LearnerDesign.title(19),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fr
                                ? 'Enregistrées sur cet appareil'
                                : 'Saved on this device',
                            style: LearnerDesign.body(13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: sessions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        if (snapshot.hasError)
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              fr
                                  ? 'Impossible de lire les séances enregistrées.'
                                  : 'Could not read saved sessions.',
                              style: LearnerDesign.body(),
                            ),
                          );
                        final rows = snapshot.data ?? [];
                        if (rows.isEmpty)
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              fr
                                  ? 'Ta prochaine séance apparaîtra ici.'
                                  : 'Your next session will appear here.',
                              style: LearnerDesign.body(),
                            ),
                          );
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final row = rows[index];
                            return ListTile(
                              selected: row['id'] == activeSessionId,
                              selectedTileColor: LearnerDesign.sky,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: const PrepSkulIcon(PrepSkulGlyph.learn),
                              title: Text(
                                row['title']!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: LearnerDesign.text(size: 15),
                              ),
                              onTap: () {
                                Navigator.pop(drawerContext);
                                onSelectSession?.call(row['id']!);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
