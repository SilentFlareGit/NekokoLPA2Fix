import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import '../services/log_buffer.dart';
import '../widgets/styled_header_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AppLogsPage extends StatefulWidget {
  const AppLogsPage({super.key});

  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

class _AppLogsPageState extends State<AppLogsPage> {
  final List<LogRecord> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<LogRecord>? _subscription;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _subscription = Logger.root.onRecord.listen((record) {
      if (mounted) {
        setState(() {
          _logs.add(record);
        });
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }
      }
    });
  }

  void _loadLogs() {
    setState(() {
      _logs.clear();
      _logs.addAll(LogBuffer().logs);
    });
    // Scroll to bottom initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StyledHeaderScaffold(
      title: AppLocalizations.of(context)!.applicationLogs,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final color = _getLevelColor(log.level);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: SelectableText.rich(
                    TextSpan(
                      style: AppTheme.mono(const TextStyle()),
                      children: [
                        TextSpan(
                          text:
                              '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')} ',
                          style: AppTheme.mono(
                            TextStyle(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVerySubtle(context),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: '[${log.loggerName}] ',
                          style: AppTheme.mono(
                            TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: log.message,
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                        if (log.error != null)
                          TextSpan(
                            text: '\nERR: ${log.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        if (log.stackTrace != null)
                          TextSpan(
                            text: '\n${log.stackTrace}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                  onPressed: _loadLogs,
                  tooltip: AppLocalizations.of(context)!.refreshReload,
                ),
                IconButton(
                  icon: Icon(
                    _autoScroll
                        ? Icons.vertical_align_bottom
                        : Icons.vertical_align_center,
                    color: _autoScroll
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                  tooltip: AppLocalizations.of(context)!.toggleAutoScroll,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    final text = _logs
                        .map(
                          (l) =>
                              "${l.time} [${l.loggerName}] ${l.level}: ${l.message}",
                        )
                        .join("\n");
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.appLogsCopied,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(Level level) {
    if (level == Level.SEVERE) return Colors.red;
    if (level == Level.WARNING) return Colors.orange;
    if (level == Level.INFO) return Colors.blue;
    return Colors.grey;
  }
}
