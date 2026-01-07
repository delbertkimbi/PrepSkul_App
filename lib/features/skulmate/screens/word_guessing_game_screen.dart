import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../services/tts_service.dart';
import '../services/sound_service.dart';
import 'dart:math' as math;

/// Interactive word guessing game screen
class WordGuessingGameScreen extends StatefulWidget {
  final GameModel game;

  const WordGuessingGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<WordGuessingGameScreen> createState() => _WordGuessingGameScreenState();
}

class _WordGuessingGameScreenState extends State<WordGuessingGameScreen> {
  int _currentIndex = 0;
  List<WordGuessItem> _wordItems = [];
  Map<int, String> _userGuesses = {}; // position -> letter
  Map<String, int> _availableLetters = {}; // letter -> count
  ConfettiController? _confettiController;
  bool _showDefinition = false;
  bool _isTTSEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    TTSService().initialize();
    SoundService().initialize();
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    TTSService().dispose();
    SoundService().dispose();
    super.dispose();
  }

  void _initializeGame() {
    // Convert game items to word guessing items
    _wordItems = widget.game.items.map((item) {
      final word = (item.correctAnswer ?? item.blankText ?? '').toString().toUpperCase();
      final question = item.question ?? '';
      final explanation = item.explanation ?? '';
      
      // Create partial word (show some letters, hide others)
      final partialWord = _createPartialWord(word);
      
      // Create available letters from the word
      final letters = _createAvailableLetters(word);
      
      return WordGuessItem(
        word: word,
        partialWord: partialWord,
        question: question,
        explanation: explanation,
        availableLetters: letters,
      );
    }).toList();

    // Initialize first word
    if (_wordItems.isNotEmpty) {
      _initializeCurrentWord();
    }
  }

  String _createPartialWord(String word) {
    if (word.isEmpty) return '';
    
    final random = math.Random();
    final positions = List.generate(word.length, (i) => i);
    positions.shuffle(random);
    
    // Show 30-50% of letters
    final showCount = (word.length * 0.3).ceil();
    final shownPositions = positions.take(showCount).toSet();
    
    return word.split('').asMap().entries.map((entry) {
      return shownPositions.contains(entry.key) ? entry.value : '_';
    }).join(' ');
  }

  Map<String, int> _createAvailableLetters(String word) {
    final letters = <String, int>{};
    for (final char in word.split('')) {
      if (char != ' ') {
        letters[char] = (letters[char] ?? 0) + 1;
      }
    }
    return letters;
  }

  void _initializeCurrentWord() {
    final currentItem = _wordItems[_currentIndex];
    _userGuesses = {};
    _availableLetters = Map.from(currentItem.availableLetters);
    
    // Pre-fill shown letters
    final partial = currentItem.partialWord.split(' ');
    for (int i = 0; i < partial.length && i < currentItem.word.length; i++) {
      if (partial[i] != '_' && partial[i].isNotEmpty) {
        _userGuesses[i] = partial[i];
        // Remove pre-filled letters from available
        if (_availableLetters.containsKey(partial[i])) {
          _availableLetters[partial[i]] = _availableLetters[partial[i]]! - 1;
          if (_availableLetters[partial[i]] == 0) {
            _availableLetters.remove(partial[i]);
          }
        }
      }
    }
  }

  void _onLetterTap(String letter) {
    if (!_availableLetters.containsKey(letter) || _availableLetters[letter]! <= 0) {
      SoundService().playIncorrect();
      return;
    }

    // Find first empty position
    final currentItem = _wordItems[_currentIndex];
    final wordLength = currentItem.word.length;
    int? emptyPosition;
    
    for (int i = 0; i < wordLength; i++) {
      if (!_userGuesses.containsKey(i) || _userGuesses[i] == null) {
        emptyPosition = i;
        break;
      }
    }

    if (emptyPosition != null) {
      safeSetState(() {
        _userGuesses[emptyPosition!] = letter;
        _availableLetters[letter] = _availableLetters[letter]! - 1;
        if (_availableLetters[letter] == 0) {
          _availableLetters.remove(letter);
        }
      });

      SoundService().playClick();
      _checkWordComplete();
    } else {
      SoundService().playIncorrect();
    }
  }

  void _onPositionTap(int position) {
    if (_userGuesses.containsKey(position) && _userGuesses[position] != null) {
      final letter = _userGuesses[position]!;
      safeSetState(() {
        _userGuesses.remove(position);
        _availableLetters[letter] = (_availableLetters[letter] ?? 0) + 1;
      });
      SoundService().playClick();
    }
  }

  void _checkWordComplete() {
    final currentItem = _wordItems[_currentIndex];
    final guessedWord = List.generate(
      currentItem.word.length,
      (i) => _userGuesses[i] ?? '',
    ).join('');

    if (guessedWord == currentItem.word) {
      // Word is correct!
      SoundService().playWordComplete();
      SoundService().playCelebration();
      
      if (_isTTSEnabled) {
        TTSService().speak('Correct! ${currentItem.word}');
      }

      _showWordCompleteDialog();
    }
  }

  void _showWordCompleteDialog() {
    final currentItem = _wordItems[_currentIndex];
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController!.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        children: [
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.celebration_rounded, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Correct!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Word: ${currentItem.word}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (currentItem.explanation.isNotEmpty) ...[
                    Text(
                      'Definition:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentItem.explanation,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _confettiController?.dispose();
                  Navigator.pop(context);
                  _nextWord();
                },
                child: Text(
                  'Next Word',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController!,
                blastDirectionality: BlastDirectionality.explosive,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 80,
                gravity: 0.1,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                  AppTheme.primaryColor,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextWord() {
    if (_currentIndex < _wordItems.length - 1) {
      safeSetState(() {
        _currentIndex++;
        _showDefinition = false;
      });
      _initializeCurrentWord();
    } else {
      // Game complete
      _showGameCompleteDialog();
    }
  }

  void _showGameCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Game Complete!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Congratulations! You completed all ${_wordItems.length} words!',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_wordItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Word Guessing')),
        body: Center(child: Text('No words available')),
      );
    }

    final currentItem = _wordItems[_currentIndex];
    final progress = (_currentIndex + 1) / _wordItems.length;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.game.title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTTSEnabled ? Icons.volume_up : Icons.volume_off,
              color: AppTheme.textDark,
              size: 20,
            ),
            onPressed: () {
              safeSetState(() {
                _isTTSEnabled = !_isTTSEnabled;
                TTSService().setEnabled(_isTTSEnabled);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Word ${_currentIndex + 1} of ${_wordItems.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question/Hint
                  if (currentItem.question.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hint',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentItem.question,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Word display
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Guess the word',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: List.generate(
                            currentItem.word.length,
                            (index) => _buildLetterBox(index),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Available letters
                  Text(
                    'Available Letters',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableLetters.entries.map((entry) {
                      return _buildAvailableLetter(entry.key, entry.value);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterBox(int position) {
    final currentItem = _wordItems[_currentIndex];
    final letter = _userGuesses[position];
    final isEmpty = letter == null || letter.isEmpty;

    return InkWell(
      onTap: () => _onPositionTap(position),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.white : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? Colors.grey[300]! : AppTheme.primaryColor,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            isEmpty ? '' : letter,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isEmpty ? AppTheme.textMedium : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableLetter(String letter, int count) {
    return InkWell(
      onTap: () => _onLetterTap(letter),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor, width: 2),
        ),
        child: Column(
          children: [
            Text(
              letter,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            if (count > 1)
              Text(
                'x$count',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppTheme.textMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Model for word guessing items
class WordGuessItem {
  final String word;
  final String partialWord;
  final String question;
  final String explanation;
  final Map<String, int> availableLetters;

  WordGuessItem({
    required this.word,
    required this.partialWord,
    required this.question,
    required this.explanation,
    required this.availableLetters,
  });
}

