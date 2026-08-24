import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../domain/parent_phrases.dart';
import '../services/parent_voice_store.dart';
import '../services/primar_voice.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// Where a parent records their own voice.
///
/// ## The design constraint that shapes everything here
///
/// A parent in a house with one phone will be interrupted. So this is built to
/// be abandoned: each line saves the moment it is recorded, the list can be
/// left at any point, and a child hears whichever lines exist. Nothing is
/// all-or-nothing, and there is no "finish" gate.
///
/// That is why the phrase list is six lines and not forty, and why they are the
/// emotional moments rather than the instructional ones — praise, patience,
/// a nudge. Nobody needs their mother to read out "which one has the most".
///
/// ## Privacy is structural, not promised
///
/// The audio is written to the app's private directory and never leaves the
/// device: there is no upload path in this code, and no synthesis provider is
/// involved. Deleting is a file delete and it is complete, because there is no
/// second copy anywhere to revoke.
class RecordVoiceScreen extends StatefulWidget {
  const RecordVoiceScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

class _RecordVoiceScreenState extends State<RecordVoiceScreen> {
  final AudioRecorder _recorder = AudioRecorder();

  Set<String> _done = {};
  String? _recordingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final done = await ParentVoiceStore.instance.recorded();
    if (mounted) setState(() => _done = done);
  }

  Future<void> _toggle(ParentPhrase phrase) async {
    if (_recordingId == phrase.id) {
      await _stop();
      return;
    }
    if (_recordingId != null) await _stop();

    try {
      if (!await _recorder.hasPermission()) {
        // Refused, or no microphone. Said plainly and without blocking the
        // rest of the screen — a parent can still leave with the lines they
        // already have.
        setState(() => _error = 'We need permission to use the microphone.');
        return;
      }
      final path = await ParentVoiceStore.instance.pathFor(phrase.id);
      if (path == null) {
        setState(() => _error = 'No room to save on this phone.');
        return;
      }

      // Stop the app talking before the microphone opens, or the recording
      // captures the guide's voice underneath the parent's.
      await PrimarVoice.instance.interrupt();

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path,
      );
      setState(() {
        _recordingId = phrase.id;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _recordingId = null;
        _error = 'That did not record. Try once more.';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _recorder.stop();
    } catch (_) {
      // Nothing to do — the file either landed or it did not, and _refresh
      // reads the truth off disk rather than trusting this call.
    }
    if (mounted) setState(() => _recordingId = null);
    await _refresh();
  }

  Future<void> _play(String id) async {
    final f = await ParentVoiceStore.instance.recordingFor(id);
    if (f != null) await PrimarVoice.instance.playFile(f.path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Mate(mood: Mood.happy, size: 72)),
        const SizedBox(height: 12),
        Text('Record your voice',
            textAlign: TextAlign.center, style: PrimarTheme.display(24)),
        const SizedBox(height: 6),
        Text(
          'Your child will hear you at the moments that matter. '
          'Say each line the way you would say it to them.',
          textAlign: TextAlign.center,
          style: PrimarTheme.body(13.5, color: PrimarTheme.muted),
        ),
        const SizedBox(height: 6),
        Text('Stays on this phone. Never sent anywhere.',
            textAlign: TextAlign.center,
            style: PrimarTheme.body(12, color: PrimarTheme.teal)),
        const SizedBox(height: 18),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PrimarTheme.tintYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!, style: PrimarTheme.body(13)),
          ),
          const SizedBox(height: 14),
        ],

        for (final phrase in parentPhrases)
          _PhraseRow(
            phrase: phrase,
            recorded: _done.contains(phrase.id),
            recording: _recordingId == phrase.id,
            onToggle: () => _toggle(phrase),
            onPlay: () => _play(phrase.id),
          ),

        const SizedBox(height: 20),
        PaperButton(
          onPressed: () async {
            await _stop();
            widget.onDone();
          },
          // Never "finish" — there is nothing to complete. A parent who
          // recorded two lines is done if they say they are.
          child: Text(_done.isEmpty ? 'Skip for now' : 'Done',
              style: PrimarTheme.display(18,
                  color: Colors.white, weight: FontWeight.w700)),
        ),
        if (_done.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              await ParentVoiceStore.instance.deleteAll();
              await _refresh();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Delete my recordings',
                  textAlign: TextAlign.center,
                  style: PrimarTheme.body(13, color: PrimarTheme.muted)),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhraseRow extends StatelessWidget {
  const _PhraseRow({
    required this.phrase,
    required this.recorded,
    required this.recording,
    required this.onToggle,
    required this.onPlay,
  });

  final ParentPhrase phrase;
  final bool recorded;
  final bool recording;
  final VoidCallback onToggle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: PrimarTheme.tile(
          border: recording
              ? PrimarTheme.orange
              : recorded
                  ? PrimarTheme.teal
                  : null,
          fill: recording
              ? PrimarTheme.tintYellow
              : recorded
                  ? PrimarTheme.tintTeal
                  : null,
          lift: recording ? 7 : 3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What to say, in quotes, so it reads as speech rather than
                  // as an instruction to be obeyed.
                  Text('"${phrase.prompt}"', style: PrimarTheme.display(16)),
                  const SizedBox(height: 3),
                  // Knowing the moment changes how a person says the line.
                  Text(phrase.when,
                      style: PrimarTheme.body(12, color: PrimarTheme.muted)),
                ],
              ),
            ),
            if (recorded && !recording)
              GestureDetector(
                onTap: onPlay,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.volume_up_rounded,
                      color: PrimarTheme.teal, size: 24),
                ),
              ),
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording ? PrimarTheme.orange : PrimarTheme.tintBlue,
                ),
                child: Icon(
                  recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: recording ? Colors.white : PrimarTheme.blue,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
