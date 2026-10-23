import '../services/learning_activity_store.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Bundled, deterministic practice: no network, generated answers or mastery claims.
class MateLocalLessonScreen extends StatefulWidget {
  const MateLocalLessonScreen({super.key, this.counting = false});
  final bool counting;
  @override
  State<MateLocalLessonScreen> createState() => _MateLocalLessonScreenState();
}

class _MateLocalLessonScreenState extends State<MateLocalLessonScreen> {
  int step = 0;
  int? answer;
  double force = 10;
  final Set<int> counted = {};
  bool ready = false;
  String? saveError;
  late final String key;
  bool get fr => Localizations.localeOf(context).languageCode == 'fr';
  String t(String en, String french) => fr ? french : en;
  int get correct => widget.counting ? 4 : 5;
  @override
  void initState() {
    super.initState();
    key =
        'mate_local_v1_${SupabaseService.currentUser?.id ?? 'guest'}_${widget.counting ? 'counting' : 'forces'}';
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(key) ?? 0;
      if (mounted)
        setState(() {
          step = saved.clamp(0, 3);
          ready = true;
        });
    } catch (_) {
      if (mounted) setState(() => ready = true);
    }
  }

  Future<void> _next() async {
    final next = (step + 1).clamp(0, 3);
    setState(() {
      step = next;
      answer = null;
    });
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setInt(key, step)) throw StateError('save');
      if (mounted) setState(() => saveError = null);
    } catch (_) {
      if (mounted)
        setState(
          () => saveError = t(
            'Couldn’t save on this device.',
            'Enregistrement impossible sur cet appareil.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.counting
        ? t('Count to four', 'Compter jusqu’à quatre')
        : t('Force and motion', 'Force et mouvement');
    final stages = [
      t('Goal', 'Objectif'),
      t('Explore', 'Explorer'),
      t('Try', 'Essayer'),
      t('Review', 'Bilan'),
    ];
    return Scaffold(
      backgroundColor: LearnerDesign.canvas,
      appBar: AppBar(title: Text(title, style: LearnerDesign.title(22))),
      body: !ready
          ? const Center(child: Text('…'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const PrepSkulIcon(PrepSkulGlyph.offline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(
                          'On this device · works without AI',
                          'Sur cet appareil · sans IA',
                        ),
                        style: LearnerDesign.body(13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    4,
                    (i) => Chip(
                      backgroundColor: i == step
                          ? LearnerDesign.sky
                          : Colors.white,
                      label: Text(
                        '${i + 1}. ${stages[i]}',
                        style: LearnerDesign.text(size: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  step == 0
                      ? (widget.counting
                            ? t('How many can you see?', 'Combien en vois-tu ?')
                            : t(
                                'What changes when you push harder?',
                                'Que change une poussée plus forte ?',
                              ))
                      : step == 1
                      ? t('Try it yourself', 'À toi d’essayer')
                      : step == 2
                      ? t('Your turn', 'À ton tour')
                      : t('Look what you explored', 'Ce que tu as exploré'),
                  style: LearnerDesign.title(27),
                ),
                const SizedBox(height: 16),
                if (step < 2) ...[
                  Text(
                    widget.counting
                        ? t(
                            'Touch each dot. Count it once.',
                            'Touche chaque point. Compte-le une fois.',
                          )
                        : t(
                            'With the same mass, a greater net force causes greater acceleration. Our block has a mass of 2 kg.',
                            'À masse égale, une force résultante plus grande produit une accélération plus grande. Notre bloc a une masse de 2 kg.',
                          ),
                    style: LearnerDesign.text(size: widget.counting ? 21 : 17),
                  ),
                  const SizedBox(height: 24),
                  if (widget.counting) ...[
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: List.generate(
                        4,
                        (i) => Semantics(
                          label: t('Dot ${i + 1}', 'Point ${i + 1}'),
                          selected: counted.contains(i),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: counted.contains(i)
                                    ? LearnerDesign.ink
                                    : LearnerDesign.blue,
                              ),
                              onPressed: () => setState(() => counted.add(i)),
                              child: Text(
                                counted.contains(i) ? '${i + 1}' : '●',
                                style: const TextStyle(fontSize: 27),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${counted.length} / 4',
                      style: LearnerDesign.title(28),
                    ),
                    TextButton(
                      onPressed: () => setState(counted.clear),
                      child: Text(t('Count again', 'Recompter')),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: LearnerDesign.surface(selected: true),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: LearnerDesign.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '2 kg',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${force.round()} N →',
                                      style: LearnerDesign.title(26),
                                    ),
                                    LinearProgressIndicator(
                                      value: force / 20,
                                      minHeight: 8,
                                      color: LearnerDesign.ink,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'a = F ÷ m = ${force.round()} ÷ 2 = ${(force / 2).toStringAsFixed(1)} m/s²',
                            style: LearnerDesign.text(size: 17),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: force,
                      min: 2,
                      max: 20,
                      divisions: 9,
                      label: '${force.round()} N',
                      semanticFormatterCallback: (v) => '${v.round()} newtons',
                      onChanged: (v) => setState(() => force = v),
                    ),
                    Text(
                      t(
                        'Move the slider to change the net force.',
                        'Déplace le curseur pour changer la force résultante.',
                      ),
                      style: LearnerDesign.body(14),
                    ),
                  ],
                ],
                if (step == 2) ...[
                  Text(
                    widget.counting
                        ? t(
                            'How many dots did you count?',
                            'Combien de points as-tu comptés ?',
                          )
                        : t(
                            'A 10 N net force acts on a 2 kg block. What is its acceleration?',
                            'Une force résultante de 10 N agit sur un bloc de 2 kg. Quelle est son accélération ?',
                          ),
                    style: LearnerDesign.text(size: 20),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: (widget.counting ? [3, 4, 5] : [2, 5, 10])
                        .map(
                          (n) => SizedBox(
                            width: 90,
                            height: 60,
                            child: OutlinedButton(
                              onPressed: answer == correct
                                  ? null
                                  : () {
                                      setState(() => answer = n);
                                      LearningActivityStore.record(
                                        'practice',
                                        concept: widget.counting
                                            ? 'Counting'
                                            : 'Forces',
                                        correct: n == correct,
                                      );
                                    },
                              child: Text(
                                '$n${widget.counting ? '' : ' m/s²'}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (answer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        answer == correct
                            ? t(
                                'Yes! ${widget.counting ? 'Four dots.' : '10 ÷ 2 = 5 m/s².'}',
                                'Oui ! ${widget.counting ? 'Quatre points.' : '10 ÷ 2 = 5 m/s².'}',
                              )
                            : widget.counting
                            ? t(
                                'Try touching each dot once: 1, 2, 3, 4. Then choose again.',
                                'Touche chaque point une fois : 1, 2, 3, 4. Puis réessaie.',
                              )
                            : t(
                                'Divide the force by the mass: 10 ÷ 2. Try again.',
                                'Divise la force par la masse : 10 ÷ 2. Réessaie.',
                              ),
                        style: LearnerDesign.text(size: 18),
                      ),
                    ),
                ],
                if (step == 3) ...[
                  const PrepSkulIcon(PrepSkulGlyph.practice, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    widget.counting
                        ? t(
                            'You practised counting each dot once.',
                            'Tu as compté chaque point une fois.',
                          )
                        : t(
                            'You explored how net force changes acceleration and checked a = F ÷ m.',
                            'Tu as exploré le lien entre force et accélération, puis vérifié a = F ÷ m.',
                          ),
                    style: LearnerDesign.text(size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      'Practice is saved on this device only. This is not a synced mastery score.',
                      'Cet entraînement est enregistré uniquement sur cet appareil. Ce n’est pas un score de maîtrise synchronisé.',
                    ),
                    style: LearnerDesign.body(14),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        step = 0;
                        answer = null;
                        counted.clear();
                      });
                      _save();
                    },
                    child: Text(t('Explore again', 'Recommencer')),
                  ),
                ],
                if (saveError != null)
                  Text(saveError!, style: LearnerDesign.body(14)),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: !ready || (step == 2 && answer != correct)
                ? null
                : step == 3
                ? () => Navigator.pop(context)
                : _next,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                step == 3
                    ? t('Back to Mate', 'Retour à Mate')
                    : t('Continue', 'Continuer'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
