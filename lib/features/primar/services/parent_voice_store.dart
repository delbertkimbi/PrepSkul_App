import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/parent_phrases.dart';

/// The parent's own recordings, on their own phone.
///
/// ## Where the audio lives, and why that is the whole privacy story
///
/// In the app's private support directory. It is never uploaded, never sent to
/// a synthesis provider, and never leaves the device — which is not a policy
/// promise, it is a consequence of there being no code anywhere that transmits
/// it.
///
/// That is the difference between this and cloning. A clone requires shipping a
/// parent's voice to a third party and trusting a retention policy. A recording
/// requires nothing of anyone.
///
/// Deletion is a file delete, and it is complete. There is no copy to revoke.
class ParentVoiceStore {
  ParentVoiceStore._();

  static final ParentVoiceStore instance = ParentVoiceStore._();

  Directory? _dir;

  Future<Directory?> _folder() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/parent_voice');
      if (!await dir.exists()) await dir.create(recursive: true);
      return _dir = dir;
    } catch (e) {
      // No storage means no parent voice, and the app carries on with the
      // teaching voice. Never fatal.
      debugPrint('[ParentVoiceStore] unavailable: $e');
      return null;
    }
  }

  Future<String?> pathFor(String phraseId) async {
    final dir = await _folder();
    if (dir == null) return null;
    return '${dir.path}/$phraseId.m4a';
  }

  /// The file for [phraseId], or null if it has not been recorded.
  Future<File?> recordingFor(String phraseId) async {
    final p = await pathFor(phraseId);
    if (p == null) return null;
    final f = File(p);
    // A zero-byte file is a recording that was interrupted. Treating it as
    // present would play silence at the exact moment a child expects to hear
    // their mother, which is worse than falling back to the teaching voice.
    if (!await f.exists() || await f.length() < 1024) return null;
    return f;
  }

  /// Which phrases are done.
  Future<Set<String>> recorded() async {
    final out = <String>{};
    for (final p in parentPhrases) {
      if (await recordingFor(p.id) != null) out.add(p.id);
    }
    return out;
  }

  /// True once there is at least one usable recording.
  ///
  /// Deliberately not "all of them". A parent who records two lines and puts
  /// the phone down should still have their child hear those two — an
  /// all-or-nothing rule would throw away the effort of every parent who was
  /// interrupted, which in a house with one phone is most of them.
  Future<bool> get hasAny async => (await recorded()).isNotEmpty;

  Future<void> delete(String phraseId) async {
    final f = await recordingFor(phraseId);
    try {
      if (f != null) await f.delete();
    } catch (e) {
      debugPrint('[ParentVoiceStore] could not delete $phraseId: $e');
    }
  }

  /// Removes every recording. For a parent who changes their mind.
  Future<void> deleteAll() async {
    for (final p in parentPhrases) {
      await delete(p.id);
    }
  }
}
