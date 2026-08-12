import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../adapter/euicc_adapter.dart';
import '../theme/app_theme.dart';
import 'profiles_screen/reader_dropdown.dart';

class SigningConfirmationDialog extends StatefulWidget {
  final String smdpAddress;
  final String matchingId;
  final List<Reader> readers;
  final Future<String?> Function(
    Reader reader,
    void Function(String status) updateStatus,
  )
  onSign;
  final int? tac;
  final int? imeiHigh;
  final int? imeiLow;

  const SigningConfirmationDialog({
    super.key,
    required this.smdpAddress,
    required this.matchingId,
    required this.readers,
    required this.onSign,
    this.tac,
    this.imeiHigh,
    this.imeiLow,
  });

  @override
  State<SigningConfirmationDialog> createState() =>
      _SigningConfirmationDialogState();
}

class _SigningConfirmationDialogState extends State<SigningConfirmationDialog> {
  late Reader? _selectedReader;
  bool _isSigning = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _selectedReader = widget.readers.isNotEmpty ? widget.readers.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const showFullEid = true;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(l10n.authorizeSigning),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.signingDescription,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  _buildInfoRow(context, l10n.smdpAddress, widget.smdpAddress),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, l10n.message, widget.matchingId),

                  if (widget.tac != null ||
                      widget.imeiHigh != null ||
                      widget.imeiLow != null) ...[
                    const SizedBox(height: 12),
                    _buildParamsRow(context),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    '${l10n.selectReaderTitle}:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurfaceSubtle(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  () {
                    void Function(Reader?)? onChanged;
                    if (!_isSigning) {
                      onChanged = (Reader? r) =>
                          setState(() => _selectedReader = r);
                    }
                    return buildReaderDropdown(
                      context: context,
                      selectedReader: _selectedReader,
                      readers: widget.readers,
                      showFullEid: showFullEid,
                      onChanged: onChanged,
                    );
                  }(),
                ],
              ),
            ),
            if (_isSigning)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (_status != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _status!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: _isSigning ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_selectedReader == null || _isSigning)
              ? null
              : _handleSign,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(l10n.sign),
        ),
      ],
    );
  }

  Future<void> _handleSign() async {
    if (_selectedReader == null) return;

    setState(() {
      _isSigning = true;
      _status = "Connecting...";
    });

    try {
      final result = await widget.onSign(_selectedReader!, (status) {
        if (mounted) setState(() => _status = status);
      });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigning = false;
          _status = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildParamsRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Params",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVerySubtle(context),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            "${widget.tac ?? 0}, ${widget.imeiHigh ?? 0}, ${widget.imeiLow ?? 0}",
            style: AppTheme.mono(
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVerySubtle(context),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            value,
            style: AppTheme.mono(
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}
