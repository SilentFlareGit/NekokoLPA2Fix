import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/styled_header_scaffold.dart';
import '../theme/app_theme.dart';
import '../settings/app_settings.dart';
import '../services/deep_link_service.dart';
import '../logic/signing_logic.dart';
import '../utils/platform_adapter.dart';
import 'dart:convert';

import 'package:logging/logging.dart';

class WebBrowserPage extends StatefulWidget {
  final String initialUrl;
  final String title;

  const WebBrowserPage({
    super.key,
    required this.initialUrl,
    required this.title,
  });

  @override
  State<WebBrowserPage> createState() => _WebBrowserPageState();
}

class _WebBrowserPageState extends State<WebBrowserPage> {
  static final Logger _log = Logger('WebBrowserPage');
  late final WebViewController _controller;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  bool _isLoading = true;
  String _pageTitle = '';
  String _currentUrl = '';

  void _handleLpaCode(String rawCode) {
    String code = rawCode;
    // Normalize
    final index = code.indexOf('1\$');
    if (index != -1) {
      code = 'LPA:${code.substring(index)}';
    } else if (!code.startsWith('LPA:')) {
      code = 'LPA:$code';
    }

    DeepLinkService().setPendingLpa(code);
    // Feedback comes from the DeepLink listener in main app

    // Optional: Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('LPA Code detected. Check pending installation.'),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title;
    _currentUrl = widget.initialUrl;

    _urlController = TextEditingController(text: widget.initialUrl);
    _urlFocusNode = FocusNode();
    _urlFocusNode.addListener(() {
      if (!_urlFocusNode.hasFocus) {
        _urlController.text = _currentUrl;
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            if (mounted && change.url != null) {
              setState(() {
                _currentUrl = change.url!;
                if (!_urlFocusNode.hasFocus) {
                  _urlController.text = _currentUrl;
                }
              });
              _injectSignBridge();
            }
          },
          onProgress: (int progress) {
            // Inject early and often to beat site checks
            if (progress > 5) {
              _injectSignBridge();
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                if (!_urlFocusNode.hasFocus) {
                  _urlController.text = _currentUrl;
                }
              });
              _injectSignBridge();
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final title = await _controller.getTitle();
              setState(() {
                _isLoading = false;
                _currentUrl = url;
                if (title != null && title.isNotEmpty) {
                  _pageTitle = title;
                }
                if (!_urlFocusNode.hasFocus) {
                  _urlController.text = _currentUrl;
                }
              });
              _injectSignBridge();
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);

            // Check for LPA scheme
            if (uri.scheme == 'lpa') {
              // Extract and handle
              final code = request.url;
              _handleLpaCode(code);
              return NavigationDecision.prevent;
            }

            // Check for install.lpa.ee
            if (uri.host == 'install.lpa.ee') {
              String? code;
              if (uri.path.startsWith('/LPA:')) {
                code = uri.path.substring(1);
              } else if (uri.path.startsWith('LPA:')) {
                code = uri.path;
              } else if (uri.queryParameters.containsKey('code')) {
                code = uri.queryParameters['code'];
              }

              if (code != null) {
                _handleLpaCode(code);
                return NavigationDecision.prevent;
              }
            }

            // Check for esimsetup domains
            if (uri.host == 'esimsetup.android.com' ||
                uri.host == 'esimsetup.lpa.ee' ||
                uri.host == 'esimsetup.apple.com') {
              if (uri.path == '/signing') {
                _handleSigningLink(uri);
                return NavigationDecision.prevent;
              }
              if (uri.queryParameters.containsKey('carddata')) {
                final code = uri.queryParameters['carddata'];
                if (code != null) {
                  _handleLpaCode(code);
                  return NavigationDecision.prevent;
                }
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'LPAChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          String? asyncId;
          try {
            final Map<String, dynamic> data = jsonDecode(message.message);

            if (data['type'] == 'openExternal') {
              final String? url = data['url'];
              if (url != null && url.isNotEmpty) {
                _log.info("Opening external link from bridge: $url");
                final uri = Uri.parse(url);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  _log.warning("Failed to launch external link: $e");
                  // Try one more time with default mode if it's a web link
                  if (url.startsWith('http')) {
                    await launchUrl(uri);
                  }
                }
              }
              return;
            }

            if (data['type'] == 'sign' ||
                (data['asyncId'] != null && data['type'] == null)) {
              asyncId = data['asyncId'];
              if (asyncId == null) {
                _log.warning("Received signing request without asyncId");
                return;
              }

              final String? smdp = data['smdp']?.toString();
              final String? text = data['text']?.toString();

              if (smdp == null || text == null) {
                _log.warning(
                  "Signing request missing smdp or text for asyncId: $asyncId",
                );
                final jsonError = jsonEncode({
                  'asyncId': asyncId,
                  'error': 'Missing smdp or text',
                });
                await _controller.runJavaScript(
                  'window.EUICCSignReject($jsonError)',
                );
                return;
              }

              final options = data['options'] as Map<String, dynamic>?;
              int? tac;
              int? imeiHigh;
              int? imeiLow;
              String? imei;

              if (options != null) {
                // Be flexible with types (string vs int)
                if (options['tac'] != null) {
                  tac = int.tryParse(options['tac'].toString());
                }
                if (options['imei'] != null) {
                  if (options['imei'] is List) {
                    final imeiParts = options['imei'] as List;
                    if (imeiParts.length == 2) {
                      imeiHigh = int.tryParse(imeiParts[0].toString());
                      imeiLow = int.tryParse(imeiParts[1].toString());
                    }
                  } else if (options['imei'] is String) {
                    imei = options['imei'] as String;
                  }
                }
              }

              try {
                final result = await SigningLogic.sign(
                  smdpAddress: smdp,
                  matchingId: text,
                  tac: tac,
                  imeiHigh: imeiHigh,
                  imeiLow: imeiLow,
                  imei: imei,
                );

                // If result is null, user cancelled.
                // GSMA specs usually expect a string or rejection.
                if (result == null) {
                  final jsonError = jsonEncode({
                    'asyncId': asyncId,
                    'error': 'User cancelled',
                  });
                  await _controller.runJavaScript(
                    'window.EUICCSignReject($jsonError)',
                  );
                } else {
                  final jsonResult = jsonEncode({
                    'asyncId': asyncId,
                    'result': result,
                  });
                  await _controller.runJavaScript(
                    'window.EUICCSignResolve($jsonResult)',
                  );
                }
              } catch (e) {
                final jsonError = jsonEncode({
                  'asyncId': asyncId,
                  'error': e.toString(),
                });
                await _controller.runJavaScript(
                  'window.EUICCSignReject($jsonError)',
                );
              }
            }
          } catch (e) {
            _log.severe("Failed to process LPAChannel message: $e");
          }
        },
      );

    _setupUserAgentAndLoad();
  }

  Future<void> _setupUserAgentAndLoad() async {
    try {
      final defaultUA = await _controller.getUserAgent();
      final appUA = AppSettings().userAgent;
      if (defaultUA != null && defaultUA.isNotEmpty) {
        await _controller.setUserAgent('$defaultUA $appUA');
      } else {
        await _controller.setUserAgent(appUA);
      }
    } catch (e) {
      // Fallback
      await _controller.setUserAgent(AppSettings().userAgent);
    }
    await _controller.loadRequest(
      Uri.parse(widget.initialUrl),
      headers: {'Referer': widget.initialUrl},
    );
    _injectSignBridge();
  }

  void _injectSignBridge() {
    const bridge = """
      (function() {
        console.log("[LPA] Bridge injection attempt...");
        
        const getLPAChannel = () => {
          if (typeof LPAChannel !== 'undefined') return LPAChannel;
          if (window.LPAChannel) return window.LPAChannel;
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.LPAChannel) {
             return { postMessage: (msg) => window.webkit.messageHandlers.LPAChannel.postMessage(msg) };
          }
          return null;
        };

        const resolveUrl = (url) => {
          if (!url || url === 'about:blank' || url.startsWith('javascript:')) return null;
          try {
             return new URL(url, document.baseURI).href;
          } catch(e) {
             return url;
          }
        }

        // Intercept window.open
        if (!window._openOverridden) {
          window._openOverridden = true;
          const originalOpen = window.open;
          window.open = function(url, target, features) {
            console.log("[LPA] window.open called", {url, target});
            const isExternalTarget = target === '_blank' || target === 'new' || target === '_new';
            const channel = getLPAChannel();
            if (isExternalTarget && channel) {
              const finalUrl = resolveUrl(url);
              if (finalUrl) {
                console.log("[LPA] window.open intercepted -> openExternal", finalUrl);
                channel.postMessage(JSON.stringify({
                  type: 'openExternal',
                  url: finalUrl
                }));
                return null;
              }
            }
            return originalOpen.apply(this, arguments);
          };
        }

        // EUICCSign bridge
        if (typeof window.EUICCSign === 'undefined' || window.EUICCSign._placeholder) {
          console.log("[LPA] Injecting EUICCSign...");
          window.EUICCSignResolvers = window.EUICCSignResolvers || {};
          window.EUICCSign = function(smdp, text, options) {
            console.log("[LPA] EUICCSign called", {smdp, text, options});
            return new Promise((resolve, reject) => {
              const asyncId = Math.random().toString(36).substring(7);
              window.EUICCSignResolvers[asyncId] = { resolve, reject };
              const channel = getLPAChannel();
              if (channel) {
                channel.postMessage(JSON.stringify({ 
                  type: 'sign',
                  asyncId, 
                  smdp, 
                  text, 
                  options 
                }));
              } else {
                console.error("[LPA] LPAChannel not found");
                reject('LPAChannel not found');
              }
            });
          };
          window.EUICCSignResolve = function(data) {
            const resolver = window.EUICCSignResolvers[data.asyncId];
            if (resolver) {
              resolver.resolve(data.result);
              delete window.EUICCSignResolvers[data.asyncId];
            }
          };
          window.EUICCSignReject = function(data) {
            const resolver = window.EUICCSignResolvers[data.asyncId];
            if (resolver) {
              resolver.reject(data.error);
              delete window.EUICCSignResolvers[data.asyncId];
            }
          };

          if (!navigator.euicc) {
            navigator.euicc = {};
          }
          navigator.euicc.sign = window.EUICCSign;
        }

        // Add global click listener for external links
        if (!window._clickIntercepted) {
          window._clickIntercepted = true;
          document.addEventListener('click', function(e) {
            let target = e.target;
            while (target && target.tagName !== 'A') {
              target = target.parentElement;
            }
            if (target && target.tagName === 'A' && target.href) {
              const targetAttr = target.getAttribute('target');
              const isBlank = targetAttr === '_blank' || targetAttr === '_new';
              
              if (isBlank) {
                 const finalUrl = target.href;
                 if (finalUrl && !finalUrl.startsWith('javascript:')) {
                   console.log("[LPA] Link click intercepted -> openExternal", finalUrl);
                   const channel = getLPAChannel();
                   if (channel) {
                     e.preventDefault();
                     channel.postMessage(JSON.stringify({
                       type: 'openExternal',
                       url: finalUrl
                     }));
                   }
                 }
              }
            }
          }, true);
        }
      })();
    """;
    _controller.runJavaScript(bridge).catchError((e) {
      // Ignore errors if controller is not yet ready
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_currentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSigningLink(Uri uri) async {
    final message = uri.queryParameters['message'];
    final callback = uri.queryParameters['callback'];
    if (message == null || callback == null) {
      _log.warning("Signing link missing message or callback: $uri");
      return;
    }

    String smdp = uri.queryParameters['smdp'] ?? "";
    String matchingId = message;

    // If smdp is missing, try to parse from message if it's in 1$smdp$matchingid format
    if (smdp.isEmpty && message.contains('\$')) {
      final parts = message.split('\$');
      if (parts.length >= 3) {
        smdp = parts[1];
        matchingId = parts[2];
      }
    }

    if (smdp.isEmpty) {
      _log.warning("Signing link missing smdp address");
      return;
    }

    int? tac;
    int? imeiHigh;
    int? imeiLow;
    final imei = uri.queryParameters['imei'];

    final tacStr = uri.queryParameters['tac'];
    final imei1Str = uri.queryParameters['imei1'];
    final imei2Str = uri.queryParameters['imei2'];

    if (tacStr != null) {
      tac = int.tryParse(tacStr);
    }

    if (imei1Str != null && imei2Str != null) {
      imeiHigh = int.tryParse(imei1Str);
      imeiLow = int.tryParse(imei2Str);
    }

    try {
      final result = await SigningLogic.sign(
        smdpAddress: smdp,
        matchingId: matchingId,
        tac: tac,
        imeiHigh: imeiHigh,
        imeiLow: imeiLow,
        imei: imei,
      );

      if (result != null) {
        final callbackUri = Uri.parse(callback);
        final Map<String, String> newParams = Map.from(
          callbackUri.queryParameters,
        );
        newParams['response'] = result;

        final finalUri = callbackUri.replace(queryParameters: newParams);
        if (await canLaunchUrl(finalUri)) {
          await launchUrl(finalUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _log.severe("Deep link signing failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _showAddressBar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StyledHeaderScaffold(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pageTitle.isEmpty ? 'Loading...' : _pageTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _currentUrl,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceSubtle(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showAddressBar ? Icons.expand_less : Icons.link,
                  color: AppTheme.onSurfaceSubtle(context),
                ),
                onPressed: () {
                  setState(() {
                    _showAddressBar = !_showAddressBar;
                  });
                },
                tooltip: _showAddressBar
                    ? 'Hide address bar'
                    : 'Show address bar',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.home_outlined,
                  color: AppTheme.onSurfaceSubtle(context),
                ),
                onPressed: () {
                  _controller.loadRequest(Uri.parse(widget.initialUrl));
                },
                tooltip: 'Home',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.open_in_browser,
                  color: AppTheme.onSurfaceSubtle(context),
                ),
                onPressed: _openInBrowser,
                tooltip: 'Open in system browser',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_showAddressBar) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AppTheme.onSurfaceSubtle(context),
                  ),
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                  tooltip: 'Back',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      readOnly: !(kDebugMode || PlatformX.isWindows),
                      onSubmitted: (kDebugMode || PlatformX.isWindows)
                          ? (value) {
                              if (value.isNotEmpty) {
                                String url = value;
                                if (!url.startsWith('http://') &&
                                    !url.startsWith('https://')) {
                                  url = 'https://$url';
                                }
                                _controller.loadRequest(Uri.parse(url));
                                _urlFocusNode.unfocus();
                              }
                            }
                          : null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppTheme.onSurfaceSubtle(context),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                        overflow: TextOverflow.ellipsis,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: AppTheme.onSurfaceSubtle(context),
                  ),
                  onPressed: () async {
                    await _controller.reload();
                  },
                  tooltip: 'Reload',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ],
      ),
      showBackButton: false,
      compact: false,
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (_urlFocusNode.hasFocus) {
                _urlFocusNode.unfocus();
              }
            },
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            // Use a linear progress indicator for a cleaner look
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: theme.colorScheme.primary,
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }
}
