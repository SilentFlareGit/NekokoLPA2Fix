import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/asn1/rsp_definitions.g.dart';
import '../theme/app_theme.dart';
import '../utils/hex_utils.dart';
import '../l10n/app_localizations.dart';

class EuiccInfoDialog {
  static void show(BuildContext context, EUICCInfo2 info2) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.dismiss,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;

        String formatVer(Uint8List? data) {
          if (data == null || data.isEmpty) return l10n.unavailable;
          return data.map((b) => b.toString()).join('.');
        }

        String formatCiList(List<SubjectKeyIdentifier>? list) {
          if (list == null || list.isEmpty) return l10n.unavailable;
          return l10n.keysCount(list.length);
        }

        Widget row(String label, String value, {bool isMono = true}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.onSurfaceSubtle(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: isMono
                      ? AppTheme.mono(
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        )
                      : TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ],
            ),
          );
        }

        final svn = info2.highestSvn ?? info2.lowestSvn;

        return Center(
          child: ScaleTransition(
            scale: anim1,
            child: Container(
              width: 380,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(color: theme.dividerColor),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.info_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          l10n.euiccInfo,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Scrollable Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          right: 8,
                        ), // Prevent scrollbar overlap
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.euiccSpecifications,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            row(
                              l10n.sasAccreditation,
                              (info2.sasAcreditationNumber ?? l10n.unavailable)
                                  .trim(),
                              isMono: false,
                            ),
                            row(
                              l10n.firmwareVersion,
                              formatVer(info2.euiccFirmwareVersion),
                            ),

                            const SizedBox(height: 8),
                            Divider(color: theme.dividerColor),
                            const SizedBox(height: 8),

                            Text(
                              l10n.platformSupport,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            row(l10n.rspVersion, formatVer(svn)),
                            row(
                              l10n.bppVersion,
                              formatVer(info2.baseProfilePackageVersion),
                            ),
                            row(
                              l10n.gpVersion,
                              formatVer(info2.globalplatformVersion),
                            ),
                            row(
                              "ETSI TS 102 241",
                              formatVer(info2.ts102241Version),
                            ),

                            const SizedBox(height: 8),
                            Divider(color: theme.dividerColor),
                            const SizedBox(height: 8),

                            Text(
                              l10n.certInfrastructure,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CiExpandableRow(
                              label: l10n.euiccSignCi,
                              items: info2.euiccCiPKIdListForSigning,
                              countValue: formatCiList(
                                info2.euiccCiPKIdListForSigning,
                              ),
                            ),
                            _CiExpandableRow(
                              label: l10n.euiccVerifyCi,
                              items: info2.euiccCiPKIdListForVerification,
                              countValue: formatCiList(
                                info2.euiccCiPKIdListForVerification,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Fixed Footer
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.done,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CiExpandableRow extends StatefulWidget {
  final String label;
  final List<Uint8List>? items;
  final String countValue;

  const _CiExpandableRow({
    required this.label,
    required this.items,
    required this.countValue,
  });

  @override
  State<_CiExpandableRow> createState() => _CiExpandableRowState();
}

class _CiExpandableRowState extends State<_CiExpandableRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasItems = widget.items != null && widget.items!.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: hasItems ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: AppTheme.onSurfaceSubtle(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.countValue,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasItems) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_expanded && hasItems)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.items!.map((ski) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.key_outlined,
                        size: 12,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          HexUtils.bytesToHex(ski).toUpperCase(),
                          style: AppTheme.mono(
                            TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
