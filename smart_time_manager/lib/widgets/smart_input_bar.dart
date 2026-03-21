import 'package:flutter/material.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/services/smart_parser.dart';
import 'package:smart_time_manager/services/asr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/providers/selected_date_provider.dart';
import 'package:intl/intl.dart';

class SmartInputBar extends ConsumerStatefulWidget {
  const SmartInputBar({super.key});

  @override
  ConsumerState<SmartInputBar> createState() => _SmartInputBarState();
}

class _SmartInputBarState extends ConsumerState<SmartInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ASRService _asrService = ASRService();
  
  bool _isExpanded = false;
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void dispose() {
    _asrService.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;

    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      final text = await _asrService.stopAndRecognize();
      if (mounted && text != null && text.isNotEmpty) {
        setState(() {
          String current = _controller.text;
          if (current.isNotEmpty && !current.endsWith(' ')) {
            current += ' ';
          }
          _controller.text = current + text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未能识别到语音或识别失败'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
      return;
    }

    try {
      final started = await _asrService.startListening();
      if (started) {
        setState(() => _isRecording = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已启动本地识别'),
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      } else if (mounted) {
        final detail = _asrService.lastError;
        if (detail != null && detail.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('语音识别启动失败：$detail'),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('语音识别启动失败'),
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('录音启动失败: $e'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 1. Parse Input
    final parsedEvent = SmartParserService.parse(text);

    // 2. Show Confirmation
    _showConfirmationSheet(parsedEvent);
  }

  void _showConfirmationSheet(PlanEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _ConfirmationSheet(
          initialEvent: event,
          onConfirm: (finalEvent) {
            ref.read(planEventsProvider.notifier).addEvent(finalEvent);
            _controller.clear();
            _focusNode.unfocus();
            setState(() => _isExpanded = false);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String hintText = '输入任务（本地识别），如"开会"';
    if (_isRecording) hintText = '正在录音... (点击停止)';
    if (_isTranscribing) hintText = '正在转文字...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    hintStyle: TextStyle(
                      color: _isRecording ? scheme.error : (_isTranscribing ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      fontStyle: (_isRecording || _isTranscribing) ? FontStyle.italic : null,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _isExpanded = true;
                    });
                  },
                  onSubmitted: (_) {
                    _handleSubmit();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording 
                      ? scheme.errorContainer.withValues(alpha: 0.45) 
                      : (_isTranscribing
                          ? scheme.primaryContainer.withValues(alpha: 0.5)
                          : scheme.primary.withValues(alpha: 0.1)),
                ),
                child: _isTranscribing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                      )
                    : Icon(
                        _isRecording ? Icons.stop : Icons.mic_rounded,
                        color: _isRecording ? scheme.error : scheme.primary,
                        size: 24,
                      ),
              ),
            ),
            if (_isExpanded || _controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: Icon(Icons.send_rounded, color: scheme.primary),
                  onPressed: _handleSubmit,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationSheet extends ConsumerStatefulWidget {
  final PlanEvent initialEvent;
  final Function(PlanEvent) onConfirm;

  const _ConfirmationSheet({required this.initialEvent, required this.onConfirm});

  @override
  ConsumerState<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends ConsumerState<_ConfirmationSheet> {
  late TextEditingController _titleController;
  late bool _isImportant;
  late bool _isUrgent;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialEvent.title);
    _isImportant = widget.initialEvent.isImportant;
    _isUrgent = widget.initialEvent.isUrgent;
    
    // Set default time to selectedDate's 00:00 if no time was parsed
    if (widget.initialEvent.startTime == null) {
      // Need to defer this slightly as ref.read shouldn't be called directly in initState 
      // without using the current provider's state properly, but since this is just 
      // reading a static value, we can do it in didChangeDependencies or directly in build.
      // We will handle it in didChangeDependencies to ensure safe access to ref.
    } else {
      _startTime = widget.initialEvent.startTime;
      _endTime = widget.initialEvent.endTime ?? _startTime?.add(const Duration(hours: 1));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startTime == null && widget.initialEvent.startTime == null) {
      final selectedDate = ref.read(selectedDateProvider);
      _startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0);
      _endTime = _startTime!.add(const Duration(hours: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('确认任务详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '任务名称', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('重要'),
                  value: _isImportant,
                  onChanged: (val) => setState(() => _isImportant = val!),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('紧急'),
                  value: _isUrgent,
                  onChanged: (val) => setState(() => _isUrgent = val!),
                ),
              ),
            ],
          ),
          ListTile(
            title: Text(_startTime == null ? '未排期 (放入收集箱)' : '开始时间: ${DateFormat('MM-dd HH:mm').format(_startTime!)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: this.context,
                initialDate: _startTime ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (date == null || !mounted) return;
              final time = await showTimePicker(
                context: this.context,
                initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
              );
              if (time == null || !mounted) return;
              setState(() {
                _startTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                if (_endTime == null || _endTime!.isBefore(_startTime!)) {
                  _endTime = _startTime!.add(const Duration(hours: 1));
                }
              });
            },
          ),
          ListTile(
            title: Text(_endTime == null ? '结束时间 (可选)' : '结束时间: ${DateFormat('MM-dd HH:mm').format(_endTime!)}'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final initialEnd = _endTime ?? (_startTime?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1)));
              final date = await showDatePicker(
                context: this.context,
                initialDate: initialEnd,
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (date == null || !mounted) return;
              final time = await showTimePicker(
                context: this.context,
                initialTime: TimeOfDay.fromDateTime(initialEnd),
              );
              if (time == null || !mounted) return;
              setState(() {
                _endTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                if (_startTime == null) {
                  _startTime = _endTime!.subtract(const Duration(hours: 1));
                } else if (_startTime!.isAfter(_endTime!)) {
                  _startTime = _endTime!.subtract(const Duration(hours: 1));
                }
              });
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final finalEvent = PlanEvent(
                title: _titleController.text,
                isImportant: _isImportant,
                isUrgent: _isUrgent,
                startTime: _startTime,
                endTime: _endTime,
              );
              widget.onConfirm(finalEvent);
            },
            child: const Text('确认添加'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
