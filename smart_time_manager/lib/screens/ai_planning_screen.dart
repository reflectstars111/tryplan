import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/services/ai_service.dart';

class AIPlanningScreen extends ConsumerStatefulWidget {
  const AIPlanningScreen({super.key});

  @override
  ConsumerState<AIPlanningScreen> createState() => _AIPlanningScreenState();
}

class _AIPlanningScreenState extends ConsumerState<AIPlanningScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // {role: 'user' | 'ai', content: '...'}
  bool _isLoading = false;
  late final AIService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
      _isLoading = true;
    });

    try {
      // Stream the response for better UX
      String fullResponse = "";
      setState(() {
        _messages.add({'role': 'ai', 'content': ''}); // Placeholder for streaming
      });

      await for (final chunk in _aiService.generateContentStream(text)) {
        fullResponse += chunk;
        if (mounted) {
          setState(() {
            _messages.last['content'] = fullResponse;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last['content'] = "抱歉，发生了错误。请检查网络或API Key设置。";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<PlanEvent> _extractEvents(String content) {
    try {
      final regex = RegExp(r'```json\s*(\[[\s\S]*?\])\s*```');
      final match = regex.firstMatch(content);
      if (match != null) {
        final jsonStr = match.group(1)!;
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) {
          return PlanEvent(
            title: e['title'] ?? '未命名任务',
            startTime: e['startTime'] != null ? DateTime.tryParse(e['startTime']) : null,
            endTime: e['endTime'] != null ? DateTime.tryParse(e['endTime']) : null,
            location: e['location'],
            isImportant: e['isImportant'] ?? false,
            isUrgent: e['isUrgent'] ?? false,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('JSON Parse Error: $e');
    }
    return [];
  }

  void _showConfirmationDialog(List<PlanEvent> events) {
    final Set<String> selectedIds = events.map((e) => e.id).toSet();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('确认添加日程'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final isSelected = selectedIds.contains(event.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.startTime != null ? DateFormat('MM-dd HH:mm').format(event.startTime!) : '待定'} - '
                        '${event.endTime != null ? DateFormat('HH:mm').format(event.endTime!) : '待定'}',
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedIds.add(event.id);
                          } else {
                            selectedIds.remove(event.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final eventsToAdd = events.where((e) => selectedIds.contains(e.id)).toList();
                    for (var event in eventsToAdd) {
                      ref.read(planEventsProvider.notifier).addEvent(event);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已添加 ${eventsToAdd.length} 个日程')),
                    );
                  },
                  child: const Text('确认添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'AI 智能规划',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text('模型: ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  DropdownButton<String>(
                    value: _aiService.currentModel,
                    isDense: true,
                    underline: Container(),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                    items: const [
                      DropdownMenuItem(
                        value: 'Qwen/Qwen3-8B',
                        child: Text('Qwen 3 (8B)'),
                      ),
                      DropdownMenuItem(
                        value: 'deepseek-ai/DeepSeek-R1-0528-Qwen3-8B',
                        child: Text('DeepSeek R1 (Qwen3-8B)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _aiService.setModel(value);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_messages.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    '我是您的智能日程助手',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('您可以试着问我：'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        label: const Text('帮我规划明天的行程'),
                        onPressed: () {
                          _controller.text = '帮我规划明天的行程';
                          _sendMessage();
                        },
                      ),
                      ActionChip(
                        label: const Text('拆解"准备周报"的任务'),
                        onPressed: () {
                          _controller.text = '拆解"准备周报"的任务';
                          _sendMessage();
                        },
                      ),
                      ActionChip(
                        label: const Text('这周末怎么安排比较轻松？'),
                        onPressed: () {
                          _controller.text = '这周末怎么安排比较轻松？';
                          _sendMessage();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final content = msg['content'] ?? '';
                final events = (!isUser && content.isNotEmpty) ? _extractEvents(content) : <PlanEvent>[];

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.replaceAll(RegExp(r'```json\s*\[[\s\S]*?\]\s*```'), '').trim(),
                          style: TextStyle(
                            color: isUser
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (events.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '推荐日程预览:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...events.map((event) => Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            color: Theme.of(context).colorScheme.surface,
                            child: ListTile(
                              dense: true,
                              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${event.startTime != null ? DateFormat('MM-dd HH:mm').format(event.startTime!) : '待定'} - '
                                '${event.endTime != null ? DateFormat('HH:mm').format(event.endTime!) : '待定'}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Icon(
                                event.isUrgent ? Icons.priority_high : Icons.event,
                                color: event.isUrgent
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.outline,
                                size: 16,
                              ),
                            ),
                          )),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_task, size: 16),
                            label: const Text('添加到日程表'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              elevation: 0,
                              side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                            onPressed: () => _showConfirmationDialog(events),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '输入您的规划需求...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
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
