import 'dart:io' show File;
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
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import 'package:prepskul/core/localization/language_service.dart';
import '../services/skulmate_service.dart';
import '../models/game_model.dart';
import 'quiz_game_screen.dart';
import 'flashcard_game_screen.dart';
import 'matching_game_screen.dart';
import 'fill_blank_game_screen.dart';
import 'word_guessing_game_screen.dart';
import 'drag_drop_game_screen.dart';
import 'simulation_game_screen.dart';
import 'mystery_game_screen.dart';
import 'escape_room_game_screen.dart';
import 'game_library_screen.dart';
import 'text_input_screen.dart';
import 'skulmate_plans_screen.dart';

/// Screen showing game generation progress
/// Accepts either pre-uploaded URLs or files to upload (navigates here first, then uploads)
class GameGenerationScreen extends StatefulWidget {
  final String? fileUrl;
  final String? imageUrl;
  final String? text;
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

  const GameGenerationScreen({
    Key? key,
    this.fileUrl,
    this.imageUrl,
    this.text,
    this.childId,
    this.difficulty,
    this.topic,
    this.numQuestions,
    this.gameType,
    this.documentToUpload,
    this.imageToUpload,
    this.imagesToUpload,
  }) : super(key: key);

  @override
  State<GameGenerationScreen> createState() => _GameGenerationScreenState();
}

class _GameGenerationScreenState extends State<GameGenerationScreen>
    with TickerProviderStateMixin {
  bool _isGenerating = true;
  String _status = 'Generating your game...';
  GameModel? _generatedGame;
  String? _error;
  String? _errorTitle;
  String? _errorDetails;

  /// When true, "Try again" is shown; when false (e.g. file too large), only Go back / Try text input.
  bool _errorRetryable = true;
  late AnimationController _animationController;
  AnimationController? _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  Animation<double>? _pulseAnimation;
  double _progress = 0.0;

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

  @override
  void dispose() {
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

  Future<void> _generateGame() async {
    try {
      String? fileUrl = widget.fileUrl;
      String? imageUrl = widget.imageUrl;

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

        safeSetState(() {
          _isGenerating = true;
          _status =
              'Uploading your file${hasImages && widget.imagesToUpload!.length > 1 ? 's' : ''}...';
        });

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
              safeSetState(
                () => _status =
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

        safeSetState(() => _status = 'Analyzing content...');
      } else {
        safeSetState(() {
          _isGenerating = true;
          _status = 'Analyzing content...';
        });
      }

      // Pull adaptive learner context from onboarding/survey so we avoid re-asking users.
      final learnerContext = await _buildLearnerContext();

      // Try auto first; if not playable, retry with quiz then flashcards then matching (vary outcome)
      const fallbackTypes = ['quiz', 'flashcards', 'matching'];
      GameModel game = await SkulMateService.generateGame(
        fileUrl: fileUrl ?? widget.fileUrl,
        imageUrl: imageUrl ?? widget.imageUrl,
        text: widget.text,
        childId: widget.childId,
        gameType: widget.gameType ?? 'auto',
        difficulty: widget.difficulty,
        topic: widget.topic,
        numQuestions: widget.numQuestions,
        learnerContext: learnerContext,
      );

      int attempt = 0;
      while (!game.isPlayable && attempt < fallbackTypes.length && mounted) {
        safeSetState(() => _status = 'Trying ${fallbackTypes[attempt]}...');
        game = await SkulMateService.generateGame(
          fileUrl: fileUrl ?? widget.fileUrl,
          imageUrl: imageUrl ?? widget.imageUrl,
          text: widget.text,
          childId: widget.childId,
          difficulty: widget.difficulty,
          topic: widget.topic,
          numQuestions: widget.numQuestions,
          gameType: fallbackTypes[attempt],
          learnerContext: learnerContext,
        );
        attempt++;
      }

      safeSetState(() {
        _generatedGame = game;
        _status = 'Game ready!';
      });

      // Validate game is playable before routing (avoid showing broken "No answer options" etc.)
      if (!game.isPlayable && mounted) {
        safeSetState(() {
          _isGenerating = false;
          _errorTitle = 'We couldn\'t create a playable game';
          _errorDetails =
              'This content doesn\'t work well for games yet. Try "Enter Text Manually" with clear notes (terms and definitions, or question-answer pairs), or upload different content.';
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
            gameScreen = FlashcardGameScreen(game: game);
            break;
          case GameType.matching:
            gameScreen = MatchingGameScreen(game: game);
            break;
          case GameType.fillBlank:
            gameScreen = WordGuessingGameScreen(game: game);
            break;
          case GameType.dragDrop:
            gameScreen = DragDropGameScreen(game: game);
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => gameScreen),
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

  Future<Map<String, dynamic>?> _buildLearnerContext() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;
      final context = <String, dynamic>{};

      final survey = await SurveyRepository.getParentSurvey(user.id);
      if (survey != null) {
        const preferredKeys = [
          'student_grade',
          'class_level',
          'curriculum',
          'exam',
          'exam_type',
          'target_exam',
          'subjects',
          'subject_preferences',
          'learning_goals',
          'learning_style',
          'preferred_language',
          'language_preference',
          'student_age_group',
        ];
        for (final key in preferredKeys) {
          final value = survey[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            context[key] = value;
          }
        }
      }

      if (widget.childId != null && widget.childId!.isNotEmpty) {
        context['childId'] = widget.childId;
      }
      context['language'] = LanguageService.languageCode;
      return context.isEmpty ? null : context;
    } catch (e) {
      LogService.warning(
        'Could not build learner context for game generation: $e',
      );
      return null;
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

  Widget _buildErrorDetailsText() {
    final details = _errorDetails;
    if (details == null || details.isEmpty) return const SizedBox.shrink();
    final lower = details.toLowerCase();
    final key = 'contact support';
    final index = lower.indexOf(key);
    if (index < 0) {
      return Text(
        details,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppTheme.textMedium,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      );
    }
    final before = details.substring(0, index);
    final clickable = details.substring(index, index + key.length);
    final after = details.substring(index + key.length);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before),
          TextSpan(
            text: clickable,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = _contactSupport,
          ),
          TextSpan(text: after),
        ],
      ),
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppTheme.textMedium,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Generating Game',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  // Animated icon with multiple effects
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing background circles
                      AnimatedBuilder(
                        animation: _pulseController ?? _animationController,
                        builder: (context, child) {
                          final pulseValue = _pulseAnimation?.value ?? 1.0;
                          return Container(
                            width: 140 + (40 * pulseValue),
                            height: 140 + (40 * pulseValue),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(
                                0.1 * pulseValue,
                              ),
                            ),
                          );
                        },
                      ),
                      // Rotating icon
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _status,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few moments...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Progress indicator with percentage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.softBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textDark.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 40,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorTitle ?? 'Something went wrong',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_errorDetails != null &&
                            _errorDetails!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildErrorDetailsText(),
                        ],
                        const SizedBox(height: 20),
                        if (_isBillingErrorState()) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SkulmatePlansScreen(),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(
                                  color: AppTheme.primaryColor.withOpacity(0.6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.account_balance_wallet_rounded,
                              ),
                              label: Text(
                                'See plans',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TextInputScreen(childId: widget.childId),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                          label: Text(
                            'Enter text manually instead',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: const BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Go back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_errorRetryable) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
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
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Try again',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGreen.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
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
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GameLibraryScreen(
                                        childId: widget.childId,
                                      ),
                                    ),
                                  );
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
    );
  }
}
