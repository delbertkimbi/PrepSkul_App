import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/widgets/prepskul_back_app_bar.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/group_classes/models/group_class_listing.dart';
import 'package:prepskul/features/group_classes/services/group_class_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateGroupClassScreen extends StatefulWidget {
  const CreateGroupClassScreen({super.key});

  @override
  State<CreateGroupClassScreen> createState() => _CreateGroupClassScreenState();
}

class _CreateGroupClassScreenState extends State<CreateGroupClassScreen> {
  static const int _stepCount = 3;
  static const List<String> _meetingDayOptions = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<DropdownMenuItem<String>> _classTypeItems = <DropdownMenuItem<String>>[
    DropdownMenuItem<String>(value: 'one_time', child: Text('One-time class')),
    DropdownMenuItem<String>(value: 'training', child: Text('Training')),
    DropdownMenuItem<String>(value: 'bootcamp', child: Text('Bootcamp')),
    DropdownMenuItem<String>(value: 'workshop', child: Text('Workshop')),
  ];

  final PageController _pageController = PageController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _subject = TextEditingController();
  final _learningFocus = TextEditingController();
  final _flyerImageUrl = TextEditingController();
  final _capacity = TextEditingController(text: '10');
  final _duration = TextEditingController(text: '60');
  final _price = TextEditingController(text: '2500');

  DateTime _startsAt = DateTime.now().add(const Duration(days: 1));
  DateTime? _scheduleEndAt;
  String _classType = 'one_time';
  final Set<String> _meetingDays = <String>{};
  int _currentStep = 0;
  bool _saving = false;
  bool _uploadingFlyer = false;
  bool _restoringDraft = false;
  static const String _draftPrefix = 'group_class_create_draft_v1';

  String get _draftKey {
    final userId = SupabaseService.currentUser?.id ?? 'anonymous';
    return '$_draftPrefix:$userId';
  }

  @override
  void initState() {
    super.initState();
    _title.addListener(_persistDraft);
    _description.addListener(_persistDraft);
    _subject.addListener(_persistDraft);
    _learningFocus.addListener(_persistDraft);
    _flyerImageUrl.addListener(_persistDraft);
    _capacity.addListener(_persistDraft);
    _duration.addListener(_persistDraft);
    _price.addListener(_persistDraft);
    _restoreDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _title.dispose();
    _description.dispose();
    _subject.dispose();
    _learningFocus.dispose();
    _flyerImageUrl.dispose();
    _capacity.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = Map<String, dynamic>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      _restoringDraft = true;
      _title.text = (parsed['title'] ?? '').toString();
      _description.text = (parsed['description'] ?? '').toString();
      _subject.text = (parsed['subject'] ?? '').toString();
      _learningFocus.text = (parsed['learningFocus'] ?? '').toString();
      _flyerImageUrl.text = (parsed['flyerImageUrl'] ?? '').toString();
      _capacity.text = (parsed['capacity'] ?? '10').toString();
      _duration.text = (parsed['duration'] ?? '60').toString();
      _price.text = (parsed['price'] ?? '2500').toString();
      _classType = (parsed['classType'] ?? 'one_time').toString();
      _currentStep = (parsed['step'] as num?)?.toInt() ?? 0;

      final startsAtRaw = parsed['startsAt']?.toString();
      final scheduleEndRaw = parsed['scheduleEndAt']?.toString();
      if (startsAtRaw != null) {
        _startsAt = DateTime.tryParse(startsAtRaw) ?? _startsAt;
      }
      _scheduleEndAt = scheduleEndRaw == null ? null : DateTime.tryParse(scheduleEndRaw);

      _meetingDays
        ..clear()
        ..addAll(((parsed['meetingDays'] as List?) ?? const <dynamic>[]).map((e) => e.toString()));

      if (mounted) setState(() {});
      if (_currentStep > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _pageController.jumpToPage(_currentStep.clamp(0, _stepCount - 1));
        });
      }
      _showMessage('Draft restored. Continue where you stopped.');
    } catch (_) {
      // Ignore invalid draft payloads.
    } finally {
      _restoringDraft = false;
    }
  }

  Future<void> _persistDraft() async {
    if (_restoringDraft) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'title': _title.text,
      'description': _description.text,
      'subject': _subject.text,
      'learningFocus': _learningFocus.text,
      'flyerImageUrl': _flyerImageUrl.text,
      'capacity': _capacity.text,
      'duration': _duration.text,
      'price': _price.text,
      'classType': _classType,
      'step': _currentStep,
      'startsAt': _startsAt.toIso8601String(),
      'scheduleEndAt': _scheduleEndAt?.toIso8601String(),
      'meetingDays': _meetingDays.toList(),
    };
    await prefs.setString(_draftKey, jsonEncode(payload));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _startsAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    _persistDraft();
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_title.text.trim().isEmpty) {
        _showMessage('Title is required.');
        return false;
      }
      if (_description.text.trim().isEmpty) {
        _showMessage('Description is required.');
        return false;
      }
      return true;
    }
    if (step == 1) {
      final flyer = _flyerImageUrl.text.trim();
      if (flyer.isNotEmpty &&
          !(flyer.startsWith('http://') || flyer.startsWith('https://'))) {
        _showMessage('Flyer URL must start with http:// or https://');
        return false;
      }
      return true;
    }
    if (step == 2) {
      final capacity = int.tryParse(_capacity.text.trim());
      final duration = int.tryParse(_duration.text.trim());
      final price = double.tryParse(_price.text.trim());
      if (capacity == null || capacity < 2 || capacity > 50) {
        _showMessage('Capacity must be between 2 and 50.');
        return false;
      }
      if (duration == null || duration < 15 || duration > 240) {
        _showMessage('Duration must be between 15 and 240 minutes.');
        return false;
      }
      if (price == null || price < 0) {
        _showMessage('Price must be 0 or greater.');
        return false;
      }
      if (_classType != 'one_time') {
        if (_scheduleEndAt == null) {
          _showMessage('Select the end date for this recurring class.');
          return false;
        }
        if (_scheduleEndAt!.isBefore(_startsAt)) {
          _showMessage('End date must be after the first class date.');
          return false;
        }
        if (_meetingDays.isEmpty) {
          _showMessage('Select at least one class day.');
          return false;
        }
      }
      return true;
    }
    return true;
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _nextStep() async {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep >= _stepCount - 1) return;
    setState(() => _currentStep += 1);
    _persistDraft();
    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _previousStep() async {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
    _persistDraft();
    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickScheduleEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _startsAt,
      lastDate: _startsAt.add(const Duration(days: 365)),
      initialDate: _scheduleEndAt ?? _startsAt.add(const Duration(days: 14)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduleEndAt = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
    _persistDraft();
  }

  void _showFlyerPromptSuggestion() {
    final title = _title.text.trim().isEmpty ? 'your class title' : _title.text.trim();
    final subject = _subject.text.trim().isEmpty ? 'your subject' : _subject.text.trim();
    final focus = _learningFocus.text.trim().isEmpty
        ? 'key learning outcomes for students'
        : _learningFocus.text.trim();
    final prompt = 'Create a clean PrepSkul branded class flyer in blue and gold. '
        'Headline: "$title". Subject: "$subject". Include this value proposition: "$focus". '
        'Style: modern educational, clear hierarchy, readable typography, mobile-first, '
        'friendly tutor-student vibe. Add CTA: "Reserve your seat on PrepSkul".';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suggested Flyer Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
          Text('Use this in ChatGPT to generate a flyer:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,),),
            const SizedBox(height: 12),
            SelectableText(prompt),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: prompt));
              if (!mounted) return;
              _showMessage('Prompt copied. Use it in ChatGPT to generate the flyer.');
            },
            child: Text('Copy Prompt', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,),),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
            
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFlyer() async {
    if (_uploadingFlyer) return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      _showMessage('Please sign in before uploading a flyer.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadingFlyer = true);
    try {
      final file = result.files.first;
      final uploadUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: file,
        documentType: 'group_class_flyer_${DateTime.now().millisecondsSinceEpoch}',
      );
      _flyerImageUrl.text = uploadUrl;
      _persistDraft();
      _showMessage('Flyer uploaded successfully.');
    } catch (e) {
      _showMessage('Flyer upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingFlyer = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2)) return;
    setState(() => _saving = true);
    try {
      final created = await GroupClassApiService.create(
        title: _title.text.trim(),
        description: _description.text.trim(),
        startsAt: _startsAt,
        durationMinutes: int.parse(_duration.text.trim()),
        capacity: int.parse(_capacity.text.trim()),
        pricePerSeat: double.parse(_price.text.trim()),
        subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
        classType: _classType,
        learningFocus: _learningFocus.text.trim().isEmpty ? null : _learningFocus.text.trim(),
        scheduleEndAt: _scheduleEndAt,
        meetingDays: _meetingDays.toList(),
        flyerImageUrl: _flyerImageUrl.text.trim().isEmpty ? null : _flyerImageUrl.text.trim(),
      );

      if (!mounted) return;
      final publishNow = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Publish now?'),
          content: const Text('Class was saved as draft. Publish now?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );

      GroupClassListing finalListing = created;
      if (publishNow == true) {
        finalListing = await GroupClassApiService.publish(created.id);
      }
      if (!mounted) return;
      await _clearDraft();
      Navigator.pop(context, finalListing);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final friendly = (msg.contains('database policy') ||
              msg.contains('row-level security') ||
              msg.contains('permission'))
          ? 'Create blocked by policy. Confirm migrations 079, 081, 082 are applied and your tutor profile is approved.'
          : (msg.contains('verified tutor')
              ? 'Only verified tutor accounts can create group classes. Please use an approved tutor account.'
              : 'Create failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PrepSkulBackAppBar(
        title: 'Create Group Class',
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: List<Widget>.generate(_stepCount, (index) {
                  final active = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index == _stepCount - 1 ? 0 : 6),
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: active ? const Color(0xFF0A2A66) : Colors.grey.shade300,
                        boxShadow: active
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF0A2A66).withOpacity(0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _currentStep == 0
                      ? 'Step 1 of 3 - Class details'
                      : _currentStep == 1
                          ? 'Step 2 of 3 - Learning + flyer'
                          : 'Step 3 of 3 - Schedule + pricing',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subject,
                        decoration: const InputDecoration(labelText: 'Subjects(comma separated)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _classType,
                        decoration: const InputDecoration(labelText: 'Session type'),
                        items: _classTypeItems,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _classType = value;
                            if (_classType == 'one_time') {
                              _scheduleEndAt = null;
                              _meetingDays.clear();
                            }
                          });
                          _persistDraft();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 8,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the class in detail, expectations and structure.',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      TextFormField(
                        controller: _learningFocus,
                        minLines: 8,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'What learners will be learning',
                          hintText: 'Write the outcomes, prerequisites and practical skills.',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _flyerImageUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Flyer image URL (optional)',
                          hintText: 'https://...',
                        ),
                      ),
                       const SizedBox(height: 10),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _uploadingFlyer ? null : _uploadFlyer,
                          icon: _uploadingFlyer
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(_uploadingFlyer ? 'Uploading...' : 'Upload flyer image'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You can upload your own flyer URL now. Auto-generated PrepSkul flyer support can be added next.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showFlyerPromptSuggestion,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Suggest AI flyer prompt'),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _capacity,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Capacity'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _duration,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Duration (mins)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price per seat (XAF)'),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Starts at'),
                        subtitle: Text(DateFormat('EEE, d MMM yyyy HH:mm').format(_startsAt)),
                        trailing: const Icon(Icons.schedule),
                        onTap: _pickDateTime,
                      ),
                      if (_classType != 'one_time') ...<Widget>[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Class runs until'),
                          subtitle: Text(
                            _scheduleEndAt == null
                                ? 'Select end date'
                                : DateFormat('EEE, d MMM yyyy').format(_scheduleEndAt!),
                          ),
                          trailing: const Icon(Icons.event_repeat),
                          onTap: _pickScheduleEndDate,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Class days',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _meetingDayOptions.map((day) {
                            final selected = _meetingDays.contains(day);
                            return FilterChip(
                              selected: selected,
                              label: Text(day),
                              selectedColor: const Color(0xFF0A2A66),
                              checkmarkColor: Colors.white,
                              labelStyle: GoogleFonts.poppins(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: selected ? const Color(0xFF0A2A66) : Colors.grey.shade500,
                              ),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _meetingDays.add(day);
                                  } else {
                                    _meetingDays.remove(day);
                                  }
                                });
                                _persistDraft();
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x11000000))),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentStep == 0 || _saving ? null : _previousStep,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : (_currentStep == _stepCount - 1 ? _save : _nextStep),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_currentStep == _stepCount - 1 ? 'Save' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

