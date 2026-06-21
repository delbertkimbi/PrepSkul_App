import 'dart:io' show File;
import 'dart:async' show unawaited;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import '../services/learner_context_service.dart';
import '../services/skulmate_service.dart';
import '../models/game_model.dart';
import 'quiz_game_screen.dart';
import 'flashcard_game_screen.dart';
import 'skulmate_scroll_feed_screen.dart';
import 'matching_game_screen.dart';
import 'fill_blank_game_screen.dart';
import 'drag_drop_game_screen.dart';
import 'puzzle_pieces_game_screen.dart';
import 'match3_game_screen.dart';
import 'bubble_pop_game_screen.dart';
import 'word_search_game_screen.dart';
import 'crossword_game_screen.dart';
import 'simulation_game_screen.dart';
import 'mystery_game_screen.dart';
import 'escape_room_game_screen.dart';
import '../utils/skulmate_client_game_policy.dart';
import '../utils/skulmate_navigation.dart';
import 'text_input_screen.dart';
import '../widgets/skulmate_generation_error_panel.dart';
import '../widgets/skulmate_paywall_sheet.dart';
import '../services/game_sound_service.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_mascot_media_widget.dart';

/// Screen showing game generation progress
/// Accepts either pre-uploaded URLs or files to upload (navigates here first, then uploads)
class GameGenerationScreen extends StatefulWidget {
  final String? fileUrl;
  final String? imageUrl;
  final String? text;
  final String? youtubeUrl;
  final String? childId;
  final String? difficulty;
  final String? topic;
  final int? numQuestions;

  /// Preferred game type from context questionnaire (e.g. quiz, flashcards, matching, auto)
  final String? gameType;

  /// Document to upload (PlatformFile on web, File on mobile)
  final dynamic documentToUpload;

  /// Image to upload (XFile from image picker) - single image
  final dynamic imageToUpload;

  /// Multiple images to upload (used when user selects several photos)
  final List<dynamic>? imagesToUpload;

  /// After flashcard generation, open vertical scroll feed instead of full game.
  final bool openAsScrollFeed;

  const GameGenerationScreen({
    Key? key,
    this.fileUrl,
    this.imageUrl,
    this.text,
    this.youtubeUrl,
    this.childId,
    this.difficulty,
    this.topic,
    this.numQuestions,
    this.gameType,
    this.documentToUpload,
    this.imageToUpload,
    this.imagesToUpload,
    this.openAsScrollFeed = false,
  }) : super(key: key);

  @override
  State<GameGenerationScreen> createState() => _GameGenerationScreenState();
}

class _GameGenerationScreenState extends State<GameGenerationScreen>
    with TickerProviderStateMixin {
  static List<String> get _stableGameTypes =>
      SkulMateClientGamePolicy.releasedApiTypes;
  bool _isGenerating = true;
  bool _generationInFlight = false;
  String _status = 'Generating your game...';
  String? _error;
  String? _errorTitle;
  String? _errorDetails;
  String? _suggestedGameType;
  String? _overrideGameType;

  /// When true, "Try again" is shown; when false (e.g. file too large), only Go back / Try text input.
  bool _errorRetryable = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  double _progress = 0.0;
  final GameSoundService _soundService = GameSoundService();
  static const List<String> _phaseLabels = <String>[
    'Uploading source',
    'Analyzing content',
    'Building game',
    'Finalizing',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _simulateProgress();
    _generateGame();
    // Soft BGM during generation flow.
    unawaited(_soundService.initialize());
    unawaited(_soundService.playResultsMusic());
  }

  void _simulateProgress() {
    // Simulate progress updates (keep text fixed to avoid jumpiness)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.2);
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.5);
      }
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.8);
      }
    });
  }

  String _gameTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'quiz':
        return 'Quiz';
      case 'flashcards':
        return 'Flashcards';
      case 'matching':
        return 'Matching';
      case 'fill_blank':
        return 'Fill Blank';
      case 'drag_drop':
        return 'Drag & Drop';
      case 'match3':
        return 'Match-3';
      case 'bubble_pop':
        return 'Bubble Pop';
      case 'word_search':
        return 'Word Search';
      case 'crossword':
        return 'Crossword';
      default:
        return 'Quiz';
    }
  }

  String _pickSuggestedGameType(String requestedGameType) {
    switch (requestedGameType) {
      case 'drag_drop':
      case 'fill_blank':
        return 'quiz';
      case 'matching':
      case 'crossword':
      case 'word_search':
        return 'flashcards';
      default:
        return 'quiz';
    }
  }

  String _rawGameTypeFromEnum(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'quiz';
      case GameType.flashcards:
        return 'flashcards';
      case GameType.matching:
        return 'matching';
      case GameType.fillBlank:
        return 'fill_blank';
      case GameType.dragDrop:
        return 'drag_drop';
      case GameType.puzzlePieces:
        return 'puzzle_pieces';
      case GameType.match3:
        return 'match3';
      case GameType.bubblePop:
        return 'bubble_pop';
      case GameType.wordSearch:
        return 'word_search';
      case GameType.crossword:
        return 'crossword';
      case GameType.simulation:
        return 'simulation';
      case GameType.mystery:
        return 'mystery';
      case GameType.escapeRoom:
        return 'escape_room';
      case GameType.diagramLabel:
        return 'diagram_label';
    }
  }

  void _setGenerationStatus(String nextStatus) {
    safeSetState(() {
      _status = nextStatus;
      final phase = _phaseIndexFromStatus(nextStatus);
      final phaseProgress = ((phase + 1) / _phaseLabels.length).clamp(0.0, 0.95);
      if (phaseProgress > _progress) {
        _progress = phaseProgress;
      }
    });
  }

  int _phaseIndexFromStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('upload')) return 0;
    if (s.contains('analyz')) return 1;
    if (s.contains('generat') || s.contains('build')) return 2;
    if (s.contains('ready') || s.contains('final')) return 3;
    return 2;
  }

  List<String> _compatibleGameTypesForCurrentInput() {
    final hasDocument = widget.documentToUpload != null || widget.fileUrl != null;
    final hasImage =
        widget.imageToUpload != null ||
        (widget.imagesToUpload?.isNotEmpty ?? false) ||
        widget.imageUrl != null;
    final hasText = widget.text != null && widget.text!.trim().isNotEmpty;
    if (hasText && !hasDocument && !hasImage) {
      return SkulMateClientGamePolicy.releasedApiTypes
          .where((t) => t != 'drag_drop' && t != 'puzzle_pieces')
          .toList(growable: false);
    }
    return SkulMateClientGamePolicy.releasedApiTypes;
  }

  Future<String?> _promptGameTypeSelection({
    required String title,
    required String message,
    required List<String> options,
  }) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium),
              ),
              const SizedBox(height: 12),
              ...options.map((raw) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _gameTypeLabel(raw),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, raw),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic());
    _animationController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  static const int _maxUploadBytes = 10 * 1024 * 1024; // 10 MB

  Future<int> _getFileSizeBytes(dynamic file) async {
    if (file == null) return 0;
    if (file is PlatformFile) return file.size;
    if (file is File) return file.lengthSync();
    // XFile
    try {
      final x = file;
      if (x is XFile) return await x.length();
    } catch (_) {}
    return 0;
  }

  String? _inferSourceFileName() {
    final doc = widget.documentToUpload;
    if (doc is PlatformFile) return doc.name;
    if (doc is File) {
      final p = doc.path.replaceAll('\\', '/');
      if (p.contains('/')) return p.split('/').last;
      return p;
    }

    final singleImage = widget.imageToUpload;
    if (singleImage is XFile) return singleImage.name;

    final manyImages = widget.imagesToUpload;
    if (manyImages != null && manyImages.isNotEmpty) {
      final first = manyImages.first;
      if (first is XFile) {
        return manyImages.length > 1
            ? '${first.name} (+${manyImages.length - 1})'
            : first.name;
      }
    }

    final typedText = (widget.text ?? '').trim();
    if (typedText.isNotEmpty) {
      final lines = typedText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final firstLine = lines.isNotEmpty ? lines.first : typedText;
      final clean = firstLine
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        final words = clean
            .split(' ')
            .where((w) => w.trim().length >= 3)
            .take(6)
            .toList();
        if (words.isNotEmpty) {
          final base = words.join('_').toLowerCase();
          return '${base}_notes.txt';
        }
      }
      return 'typed_notes.txt';
    }
    return null;
  }

  /// Topic-only intake sends [topic] without [text] so the API can generate from subject.
  String? _textForGeneration() {
    final raw = widget.text?.trim();
    final hasTopic = widget.topic != null && widget.topic!.trim().isNotEmpty;
    final hasFileSource =
        widget.documentToUpload != null ||
        widget.imageToUpload != null ||
        (widget.imagesToUpload?.isNotEmpty ?? false) ||
        (widget.fileUrl?.isNotEmpty ?? false) ||
        (widget.youtubeUrl?.isNotEmpty ?? false);

    if (hasTopic && (raw == null || raw.isEmpty) && !hasFileSource) {
      return null;
    }
    return raw;
  }

  Future<void> _generateGame() async {
    if (_generationInFlight) {
      LogService.warning(
        '🎮 [skulMate] _generateGame ignored: generation already in flight',
      );
      return;
    }
    _generationInFlight = true;
    try {
      String? fileUrl = widget.fileUrl;
      String? imageUrl = widget.imageUrl;
      var requestedGameType =
          (_overrideGameType ?? widget.gameType ?? 'auto').toLowerCase();
      final compatibleTypes = _compatibleGameTypesForCurrentInput();
      if (requestedGameType != 'auto' &&
          (!_stableGameTypes.contains(requestedGameType) ||
              !compatibleTypes.contains(requestedGameType))) {
        safeSetState(() {
          _isGenerating = false;
          _error = null;
          _errorTitle = null;
          _errorDetails = null;
          _errorRetryable = false;
          _progress = 0.0;
        });
        final selected = await _promptGameTypeSelection(
          title: 'Selected type unavailable',
          message:
              '${_gameTypeLabel(requestedGameType)} is not released for stable gameplay yet. Pick one supported option to continue.',
          options: compatibleTypes,
        );
        if (selected == null) return;
        requestedGameType = selected;
        safeSetState(() {
          _overrideGameType = selected;
          _isGenerating = true;
          _status = 'Preparing ${_gameTypeLabel(selected)}...';
          _errorRetryable = true;
        });
      }
      final allowFallback = requestedGameType == 'auto';
      _suggestedGameType = null;

      // Upload files if passed (user navigated here with files)
      final hasImages =
          widget.imagesToUpload != null && widget.imagesToUpload!.isNotEmpty;
      final hasSingleImage = widget.imageToUpload != null;
      final hasDocs = widget.documentToUpload != null;

      if (hasDocs || hasSingleImage || hasImages) {
        // Validate total size before uploading (avoid generic "Upload issue" for large files)
        int totalBytes = 0;
        if (widget.documentToUpload != null) {
          totalBytes += await _getFileSizeBytes(widget.documentToUpload);
        }
        if (widget.imageToUpload != null) {
          totalBytes += await _getFileSizeBytes(widget.imageToUpload);
        }
        if (widget.imagesToUpload != null) {
          for (final f in widget.imagesToUpload!) {
            totalBytes += await _getFileSizeBytes(f);
          }
        }
        if (totalBytes > _maxUploadBytes) {
          safeSetState(() {
            _isGenerating = false;
            _errorTitle = 'File too large';
            _errorDetails =
                'Keep files under 10 MB for best results. You can use "Enter Text Manually" or split content into smaller files.';
            _error = '$_errorTitle\n\n$_errorDetails';
            _errorRetryable = false;
            _progress = 0.0;
          });
          return;
        }

        safeSetState(() => _isGenerating = true);
        _setGenerationStatus(
          'Uploading your file${hasImages && widget.imagesToUpload!.length > 1 ? 's' : ''}...',
        );

        final user = SupabaseService.client.auth.currentUser;
        if (user == null) throw Exception('User not authenticated');

        if (widget.documentToUpload != null) {
          fileUrl = await StorageService.uploadDocument(
            userId: user.id,
            documentFile: widget.documentToUpload,
            documentType: 'skulmate_notes',
          );
        }
        // Prefer imagesToUpload when multiple; otherwise single imageToUpload
        if (hasImages) {
          final urls = <String>[];
          for (int i = 0; i < widget.imagesToUpload!.length; i++) {
            if (i > 0) {
              _setGenerationStatus(
                'Uploading image ${i + 1} of ${widget.imagesToUpload!.length}...',
              );
            }
            final url = await StorageService.uploadDocument(
              userId: user.id,
              documentFile: widget.imagesToUpload![i],
              documentType: 'skulmate_notes',
            );
            urls.add(url);
          }
          imageUrl = urls.first;
          // TODO: API could accept multiple image URLs for richer content
        } else if (hasSingleImage) {
          imageUrl = await StorageService.uploadDocument(
            userId: user.id,
            documentFile: widget.imageToUpload,
            documentType: 'skulmate_notes',
          );
        }

        _setGenerationStatus('Analyzing content...');
      } else {
        safeSetState(() => _isGenerating = true);
        _setGenerationStatus('Analyzing content...');
      }

      // Pull adaptive learner context from onboarding/survey so we avoid re-asking users.
      final learnerContext = await LearnerContextService.build(
        childId: widget.childId,
      );

      // For auto only: if not playable or unreleased, retry with released types.
      final fallbackTypes = SkulMateClientGamePolicy.autoStableApiTypes;
      _setGenerationStatus('Generating your game...');
      final sourceFileName = _inferSourceFileName();
      final generationText = _textForGeneration();
      GameModel game = await SkulMateService.generateGame(
        fileUrl: fileUrl ?? widget.fileUrl,
        imageUrl: imageUrl ?? widget.imageUrl,
        text: generationText,
        youtubeUrl: widget.youtubeUrl,
        sourceFileName: sourceFileName,
        childId: widget.childId,
        gameType: requestedGameType,
        difficulty: widget.difficulty,
        topic: widget.topic,
        numQuestions: widget.numQuestions,
        learnerContext: learnerContext,
      );

      // Keep the first ID so we can clean up unusable saved records.
      final firstGeneratedId = game.id;

      // Retry when auto returns an unreleased client type.
      if (allowFallback &&
          SkulMateClientGamePolicy.comingSoonTypes.contains(game.gameType) &&
          mounted) {
        for (final fallbackType in fallbackTypes) {
          if (fallbackType == requestedGameType) continue;
          _setGenerationStatus('Generating with $fallbackType...');
          try {
            final fallbackGame = await SkulMateService.generateGame(
              fileUrl: fileUrl ?? widget.fileUrl,
              imageUrl: imageUrl ?? widget.imageUrl,
              text: generationText,
              youtubeUrl: widget.youtubeUrl,
              sourceFileName: sourceFileName,
              childId: widget.childId,
              difficulty: widget.difficulty,
              topic: widget.topic,
              numQuestions: widget.numQuestions,
              gameType: fallbackType,
              learnerContext: learnerContext,
            );
            game = fallbackGame;
            if (SkulMateClientGamePolicy.isReleasedInClient(game.gameType) &&
                game.isPlayable) {
              break;
            }
          } catch (fallbackError) {
            LogService.warning(
              '🎮 [skulMate] Coming-soon fallback failed for $fallbackType: $fallbackError',
            );
          }
        }
      }

      if (!game.isPlayable && allowFallback && mounted) {
        for (final fallbackType in fallbackTypes) {
          if (fallbackType == requestedGameType) continue;
          _setGenerationStatus('Generating with $fallbackType...');
          try {
            final fallbackGame = await SkulMateService.generateGame(
              fileUrl: fileUrl ?? widget.fileUrl,
              imageUrl: imageUrl ?? widget.imageUrl,
              text: generationText,
              youtubeUrl: widget.youtubeUrl,
              sourceFileName: sourceFileName,
              childId: widget.childId,
              difficulty: widget.difficulty,
              topic: widget.topic,
              numQuestions: widget.numQuestions,
              gameType: fallbackType,
              learnerContext: learnerContext,
            );
            game = fallbackGame;
            if (game.isPlayable &&
                SkulMateClientGamePolicy.isReleasedInClient(game.gameType)) {
              break;
            }
          } catch (fallbackError) {
            LogService.warning(
              '🎮 [skulMate] Fallback generation failed for $fallbackType: $fallbackError',
            );
            // If billing/limit is hit, further retries are unlikely to succeed.
            final fallbackLower = fallbackError.toString().toLowerCase();
            if (fallbackLower.contains('free limit reached') ||
                fallbackLower.contains('insufficient credits') ||
                fallbackLower.contains('plan to continue') ||
                fallbackLower.contains('402')) {
              break;
            }
          }
        }
      }

      // Never silently switch from a user-selected game type.
      if (!allowFallback) {
        final generatedRawType = _rawGameTypeFromEnum(game.gameType);
        if (generatedRawType != requestedGameType) {
          if (firstGeneratedId.isNotEmpty) {
            unawaited(
              SkulMateService.deleteGame(firstGeneratedId).catchError((e) {
                LogService.warning(
                  '🎮 [skulMate] Could not delete mismatched generated game: $e',
                );
              }),
            );
          }
          safeSetState(() {
            _isGenerating = false;
            _errorTitle = 'Selected game type changed';
            _suggestedGameType = generatedRawType;
            _errorDetails =
                'You selected ${_gameTypeLabel(requestedGameType)}, but this content generated '
                '${_gameTypeLabel(generatedRawType)}. '
                'Choose "Try ${_gameTypeLabel(generatedRawType)}" to continue, or go back to upload.';
            _error = '$_errorTitle\n\n$_errorDetails';
            _errorRetryable = true;
            _progress = 0.0;
          });
          return;
        }
      }

      // If fallback/auto-switch produced a different playable game, clean up
      // the initial non-playable record to avoid duplicate/broken cards.
      if (game.isPlayable &&
          firstGeneratedId.isNotEmpty &&
          game.id.isNotEmpty &&
          game.id != firstGeneratedId) {
        unawaited(
          SkulMateService.deleteGame(firstGeneratedId).catchError((e) {
            LogService.warning(
              '🎮 [skulMate] Could not delete superseded generated game: $e',
            );
          }),
        );
      }

      _setGenerationStatus('Game ready!');

      // Block unreleased types from opening after generation.
      if (SkulMateClientGamePolicy.comingSoonTypes.contains(game.gameType) &&
          mounted) {
        LogService.warning(
          '🎮 [skulMate] Generated unreleased type ${game.gameType.name} (id=${game.id})',
        );
        if (game.id.isNotEmpty) {
          unawaited(
            SkulMateService.deleteGame(game.id).catchError((e) {
              LogService.warning(
                '🎮 [skulMate] Could not delete unreleased generated game: $e',
              );
            }),
          );
        }
        safeSetState(() {
          _isGenerating = false;
          _errorTitle = 'This game type is not available yet';
          _errorDetails =
              'We generated a preview type that is still in development. '
              'Try again with Auto or pick Quiz, Flashcards, or Matching.';
          _error = '$_errorTitle\n\n$_errorDetails';
          _errorRetryable = true;
          _progress = 0.0;
        });
        return;
      }

      // Validate game is playable before routing (avoid showing broken "No answer options" etc.)
      if (!game.isPlayable && mounted) {
        LogService.warning(
          '🎮 [skulMate] Generated game not playable '
          '(type=${game.gameType.name}, items=${game.items.length}, id=${game.id})',
        );
        // Avoid cluttering dashboard with broken, non-playable generated records.
        if (firstGeneratedId.isNotEmpty) {
          unawaited(
            SkulMateService.deleteGame(firstGeneratedId).catchError((e) {
              LogService.warning(
                '🎮 [skulMate] Could not delete non-playable generated game: $e',
              );
            }),
          );
        }
        safeSetState(() {
          _isGenerating = false;
          _errorTitle = 'We couldn\'t create a playable game';
          final suggested = _pickSuggestedGameType(requestedGameType);
          _suggestedGameType = suggested;
          _errorDetails =
              'This content does not fit ${_gameTypeLabel(requestedGameType)} well yet. '
              'You can try ${_gameTypeLabel(suggested)} now, or go back to upload another content.';
          _error = '$_errorTitle\n\n$_errorDetails';
          _errorRetryable = true;
        });
        return;
      }

      // Navigate to appropriate game screen (fromGenerationFlow so back goes to dashboard)
      if (mounted) {
        Widget gameScreen;
        switch (game.gameType) {
          case GameType.quiz:
            gameScreen = QuizGameScreen(game: game, fromGenerationFlow: true);
            break;
          case GameType.flashcards:
            gameScreen = widget.openAsScrollFeed
                ? SkulMateScrollFeedScreen(
                    seedGame: game,
                    childId: widget.childId,
                  )
                : FlashcardGameScreen(game: game);
            break;
          case GameType.matching:
            gameScreen = MatchingGameScreen(game: game);
            break;
          case GameType.fillBlank:
            gameScreen = FillBlankGameScreen(game: game);
            break;
          case GameType.dragDrop:
            gameScreen = DragDropGameScreen(game: game);
            break;
          case GameType.puzzlePieces:
            gameScreen = PuzzlePiecesGameScreen(game: game);
            break;
          case GameType.match3:
            gameScreen = Match3GameScreen(game: game);
            break;
          case GameType.bubblePop:
            gameScreen = BubblePopGameScreen(game: game);
            break;
          case GameType.wordSearch:
            gameScreen = WordSearchGameScreen(game: game);
            break;
          case GameType.crossword:
            gameScreen = CrosswordGameScreen(game: game);
            break;
          case GameType.simulation:
            gameScreen = SimulationGameScreen(game: game);
            break;
          case GameType.mystery:
            gameScreen = MysteryGameScreen(game: game);
            break;
          case GameType.escapeRoom:
            gameScreen = EscapeRoomGameScreen(game: game);
            break;
          default:
            gameScreen = QuizGameScreen(game: game, fromGenerationFlow: true);
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => gameScreen),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      LogService.error('Error generating game: $e');

      // Parse structured error message (format: "Title\n\nDetails")
      String errorTitle = 'We couldn\'t create your game right now.';
      String errorDetails = '';

      final errorStr = e.toString();

      // Check if error already has structured format (title\n\ndetails)
      if (errorStr.contains('\n\n')) {
        final parts = errorStr.split('\n\n');
        errorTitle = parts[0].replaceAll('Exception: ', '').trim();
        errorDetails = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
      } else {
        // Parse unstructured errors
        final lowerError = errorStr.toLowerCase();

        if (lowerError.contains('fileurl') ||
            lowerError.contains('text is required')) {
          errorTitle = 'Please provide content to generate a game.';
          errorDetails = 'Upload a document, image, or enter text to continue.';
        } else if (lowerError.contains('too large') ||
            lowerError.contains('file size') ||
            lowerError.contains('size limit') ||
            lowerError.contains('exceeds') ||
            lowerError.contains('payload too large') ||
            lowerError.contains('413')) {
          errorTitle = 'File too large';
          errorDetails =
              'Keep files under 10 MB for best results. Use "Enter Text Manually" or split content into smaller files.';
        } else if (lowerError.contains('permissions') ||
            lowerError.contains('rls') ||
            lowerError.contains('row-level security') ||
            lowerError.contains('upload failed') ||
            lowerError.contains('clientexception') ||
            lowerError.contains('failed to fetch')) {
          errorTitle = 'Upload didn\'t work';
          errorDetails =
              'We couldn\'t upload your file. Try "Enter Text Manually" on the upload screen, or a smaller file.';
        } else if (lowerError.contains('api endpoint not found') ||
            lowerError.contains('404')) {
          errorTitle = 'Service unavailable';
          errorDetails =
              'The game generation service may not be available. Please check your connection and try again.';
        } else if (lowerError.contains('network') ||
            lowerError.contains('connection') ||
            lowerError.contains('failed host lookup')) {
          errorTitle = 'Connection problem';
          errorDetails = 'Please check your internet connection and try again.';
        } else if (lowerError.contains('daily free limit reached') ||
            lowerError.contains('free image limit reached') ||
            lowerError.contains('free document/text limit reached') ||
            lowerError.contains('free limit reached')) {
          errorTitle = 'Free plan limit reached';
          errorDetails =
              'You have reached today\'s free limit for this upload type. Choose a plan to keep generating now, or try again tomorrow.';
        } else if (lowerError.contains('insufficient credits') ||
            lowerError.contains('top up credits')) {
          errorTitle = 'Pro required for this action';
          errorDetails =
              'This action needs a paid SkulMate plan. Please choose a plan and continue.';
        } else if (lowerError.contains('timeout') ||
            lowerError.contains('took too long')) {
          errorTitle = 'Request took too long';
          errorDetails =
              'The request is taking longer than expected. Please try again.';
        } else if (lowerError.contains('server error') ||
            lowerError.contains('500')) {
          errorTitle = 'Server error';
          errorDetails =
              'Our servers are having issues. Please try again in a few moments.';
        } else if (lowerError.contains('400') ||
            lowerError.contains('bad request') ||
            lowerError.contains('invalid')) {
          errorTitle = 'Invalid request';
          errorDetails =
              'Please make sure you\'ve uploaded a valid file or entered text.';
        } else if (lowerError.contains('invalid response format') ||
            lowerError.contains('html')) {
          errorTitle = 'Service error';
          errorDetails =
              'The server returned an unexpected response. Please try again or contact support.';
        } else {
          // Extract message from exception
          final match = RegExp(r'Exception: (.+)').firstMatch(errorStr);
          if (match != null) {
            final message = match.group(1)!;
            if (!message.toLowerCase().contains('exception')) {
              errorTitle = message;
            }
          }
          if (errorDetails.isEmpty) {
            errorDetails =
                'Please try again or contact support if the problem persists.';
          }
        }
      }

      // Last safety pass: never show raw technical/internal errors to users.
      final combinedErrorForUi = '$errorTitle\n\n$errorDetails'.toLowerCase();
      if (combinedErrorForUi.contains('cannot read properties of undefined') ||
          combinedErrorForUi.contains('reading \'0\'') ||
          combinedErrorForUi.contains('reading "0"') ||
          combinedErrorForUi.contains('failed to extract meaningful text') ||
          combinedErrorForUi.contains(
            'failed to extract text from your file',
          ) ||
          combinedErrorForUi.contains('failed to extract text from image') ||
          combinedErrorForUi.contains('openrouter api error') ||
          combinedErrorForUi.contains('stack trace') ||
          combinedErrorForUi.contains('typeerror')) {
        errorTitle = 'We couldn\'t read text from this file.';
        errorDetails =
            'We can still continue: tap "Enter text manually", or upload a clearer image, or a DOCX/TXT/PDF with readable text. '
            'If it keeps happening, contact support.';
      }

      // Split error into title and details
      final errorParts = errorDetails.isNotEmpty
          ? '$errorTitle\n\n$errorDetails'
          : errorTitle;
      final parts = errorParts.split('\n\n');

      // Non-retryable: file too large, invalid request, or missing content
      final nonRetryable =
          errorStr.toLowerCase().contains('too large') ||
          errorStr.toLowerCase().contains('file size') ||
          errorStr.toLowerCase().contains('payload too large') ||
          errorStr.toLowerCase().contains('413') ||
          errorStr.toLowerCase().contains('fileurl') ||
          errorStr.toLowerCase().contains('text is required') ||
          (parts.isNotEmpty &&
              (parts[0].toLowerCase().contains('invalid') ||
                  parts[0].toLowerCase().contains('provide content')));

      safeSetState(() {
        _isGenerating = false;
        _error = errorParts;
        _errorTitle = parts[0];
        _errorDetails = parts.length > 1 ? parts.sublist(1).join('\n\n') : null;
        _errorRetryable = !nonRetryable;
        _progress = 0.0;
      });
    } finally {
      _generationInFlight = false;
    }
  }

  Future<void> _contactSupport() async {
    try {
      final source = widget.text != null && widget.text!.trim().isNotEmpty
          ? 'manual text'
          : (widget.imageToUpload != null ||
                (widget.imagesToUpload?.isNotEmpty ?? false))
          ? 'image upload'
          : 'document upload';
      final details =
          'Hi PrepSkul Support, I need help with SkulMate.\n\n'
          'I was trying to generate a ${widget.gameType ?? 'game'} from $source'
          '${widget.topic != null && widget.topic!.trim().isNotEmpty ? ' (topic: ${widget.topic!.trim()})' : ''}.\n'
          'What I saw:\n'
          '${_errorTitle ?? 'Generation failed'}'
          '${_errorDetails != null && _errorDetails!.isNotEmpty ? '\n${_errorDetails!}' : ''}\n\n'
          'Platform: ${kIsWeb ? 'web' : 'mobile'}';
      await WhatsAppSupportService.openWhatsApp(
        context: 'skulmate_generation',
        additionalInfo: details,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isBillingErrorState() {
    final title = (_errorTitle ?? '').toLowerCase();
    final details = (_errorDetails ?? '').toLowerCase();
    final combined = '$title $details';
    return combined.contains('daily free limit') ||
        combined.contains('free plan limit') ||
        combined.contains('free limit reached') ||
        combined.contains('not enough credits') ||
        combined.contains('insufficient credits') ||
        combined.contains('top up');
  }

  IconData _phaseIcon(int index) {
    switch (index) {
      case 0:
        return Icons.file_upload_outlined;
      case 1:
        return Icons.psychology_alt_outlined;
      case 2:
        return Icons.auto_awesome_rounded;
      case 3:
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _phaseActiveColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF2563EB); // blue
      case 1:
        return const Color(0xFF7C3AED); // purple
      case 2:
        return const Color(0xFF0EA5E9); // sky
      case 3:
        return const Color(0xFF16A34A); // green
      default:
        return AppTheme.textMedium;
    }
  }

  Widget _buildProcessTimeline() {
    final activeStep = _phaseIndexFromStatus(_status);
    final phaseDescriptions = <String>[
      activeStep == 0 ? _status : 'Secure transfer complete.',
      activeStep == 1 ? _status : 'Concept map prepared.',
      activeStep == 2 ? _status : 'Questions and game logic prepared.',
      activeStep == 3 ? _status : 'Game is ready to launch.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_phaseLabels.length, (stepIndex) {
          final isDone = stepIndex < activeStep;
          final isActive = stepIndex == activeStep;
          final iconColor = isDone || isActive
              ? _phaseActiveColor(stepIndex)
              : AppTheme.textMedium;
          return Container(
            margin: EdgeInsets.only(bottom: stepIndex == _phaseLabels.length - 1 ? 0 : 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? iconColor.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? iconColor.withValues(alpha: 0.8)
                    : AppTheme.softBorder,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive
                        ? iconColor
                        : AppTheme.neutral100,
                  ),
                  child: Icon(
                    isDone ? Icons.check : _phaseIcon(stepIndex),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _phaseLabels[stepIndex],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        phaseDescriptions[stepIndex],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppTheme.textMedium,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFloatingBadge({required IconData icon, required Color color}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 12,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SkulMateGameAppBar(title: 'Generating Game'),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => unawaited(_soundService.registerUserGesture()),
        child: Container(
          color: Colors.white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.softBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textDark.withValues(alpha: 0.035),
                          blurRadius: 9,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'SkulMate',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.skyBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Processing',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedBuilder(
                          animation: _pulseController ?? _animationController,
                          builder: (context, _) {
                            final pulseValue = _pulseAnimation?.value ?? 1.0;
                            return Transform.translate(
                              offset: Offset(0, -(pulseValue - 0.5) * 6),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 106,
                                    height: 106,
                                    decoration: BoxDecoration(
                                      color: AppTheme.skyBlue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 86,
                                    height: 86,
                                    child: SkulMateMascotMediaWidget(
                                      state: SkulMateMascotState.thinking,
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -2,
                                    child: _buildFloatingBadge(
                                      icon: Icons.auto_awesome_rounded,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  Positioned(
                                    left: -4,
                                    bottom: 4,
                                    child: _buildFloatingBadge(
                                      icon: Icons.quiz_outlined,
                                      color: const Color(0xFF0EA5E9),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _status,
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We are transforming your notes into a personalized challenge.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: _progress),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, animatedValue, _) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: animatedValue.clamp(0.0, 1.0),
                                minHeight: 9,
                                backgroundColor: AppTheme.neutral100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _phaseActiveColor(_phaseIndexFromStatus(_status)),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(_progress * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildProcessTimeline(),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFAF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF9AE6A3),
                      ),
                    ),
                    child: Text(
                      'PRO TIP: Structured notes with key terms and definitions generate stronger games.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF166534),
                        height: 1.35,
                      ),
                    ),
                  ),
                ] else if (_error != null) ...[
                  SkulMateGenerationErrorPanel(
                    title: _errorTitle ?? 'Something went wrong',
                    details: _errorDetails,
                    kind: SkulMateGenerationErrorPanel.kindFromMessage(
                      '${_errorTitle ?? ''} ${_errorDetails ?? ''}',
                    ),
                    retryable: _errorRetryable,
                    suggestedGameTypeLabel: _suggestedGameType != null
                        ? _gameTypeLabel(_suggestedGameType!)
                        : null,
                    onPaywall: _isBillingErrorState()
                        ? () => SkulMatePaywallSheet.show(context)
                        : null,
                    onManualText: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TextInputScreen(childId: widget.childId),
                        ),
                      );
                    },
                    onBack: () => Navigator.pop(context),
                    onTrySuggested: _suggestedGameType != null
                        ? () {
                            final suggested = _suggestedGameType;
                            if (suggested == null) return;
                            safeSetState(() {
                              _overrideGameType = suggested;
                              _isGenerating = true;
                              _error = null;
                              _errorTitle = null;
                              _errorDetails = null;
                              _errorRetryable = true;
                              _progress = 0.0;
                              _status =
                                  'Trying ${_gameTypeLabel(suggested)}...';
                            });
                            _simulateProgress();
                            _generateGame();
                          }
                        : null,
                    onRetry: _errorRetryable
                        ? () {
                            safeSetState(() {
                              _isGenerating = true;
                              _error = null;
                              _errorTitle = null;
                              _errorDetails = null;
                              _errorRetryable = true;
                              _progress = 0.0;
                              _status = 'Analyzing content...';
                            });
                            _simulateProgress();
                            _generateGame();
                          }
                        : null,
                    onContactSupport: _contactSupport,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGreen.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 48,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _status,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Upload Another',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  SkulMateNavigation.exitToSkulMateHome(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'View Games',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
