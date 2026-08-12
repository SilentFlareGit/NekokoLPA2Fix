import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/styled_header_scaffold.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class AramInfoPage extends StatefulWidget {
  const AramInfoPage({super.key});

  @override
  State<AramInfoPage> createState() => _AramInfoPageState();
}

class _AramInfoPageState extends State<AramInfoPage> {
  static const _channel = MethodChannel('ee.nekoko.certificate_plugin');

  List<String>? _sha1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHashes();
  }

  Future<void> _loadHashes() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getCertificateHashes',
      );
      if (mounted) {
        final aramHashes = result?['aramSha1'] as List?;
        final currentHashes = result?['sha1'] as List?;
        final hashes = aramHashes?.isNotEmpty == true
            ? aramHashes
            : currentHashes;
        setState(() {
          _sha1 = hashes?.isNotEmpty == true
              ? hashes!.map((hash) => hash.toString()).toSet().toList()
              : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StyledHeaderScaffold(
      title: l10n.aramInfoTitle,
      subtitle: l10n.aramInfoSubtitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.whatIsAram),
            const SizedBox(height: 12),
            Text(
              l10n.aramDescription,
              style: TextStyle(
                color: AppTheme.onSurfaceSubtle(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, l10n.appCertHashes),
            const SizedBox(height: 12),
            Text(
              l10n.aramSigningHistoryInstruction,
              style: TextStyle(
                color: AppTheme.onSurfaceSubtle(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ...(_sha1?.map(
                  (hash) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildHashCard(context, l10n.certSha1Hash, hash),
                  ),
                ) ??
                [
                  _buildHashCard(
                    context,
                    l10n.certSha1Hash,
                    _loading ? l10n.initializing : l10n.unavailable,
                    isLoading: _loading,
                  ),
                ]),
            const SizedBox(height: 32),
            _buildSectionHeader(context, l10n.troubleshooting),
            const SizedBox(height: 16),
            _buildBulletPoint(context, l10n.troubleStep1, Icons.usb_rounded),
            _buildBulletPoint(
              context,
              l10n.troubleStep2,
              Icons.sim_card_rounded,
            ),
            _buildBulletPoint(
              context,
              l10n.troubleStep3,
              Icons.build_circle_outlined,
            ),
            _buildBulletPoint(
              context,
              l10n.troubleStep4,
              Icons.shield_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildHashCard(
    BuildContext context,
    String label,
    String hash, {
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  hash,
                  style: AppTheme.mono(
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (!isLoading && hash != "Unavailable")
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: hash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.hashCopied,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.onSurfaceSubtle(context),
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
