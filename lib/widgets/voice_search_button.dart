import 'dart:async';

import 'package:flutter/material.dart';

import '../models/speech/speech_transcription_result.dart';
import '../models/supported_language.dart';
import '../models/voice_state.dart';
import '../services/speech/speech_to_text_service.dart';
import '../services/friendly_response_service.dart';

/// Interactive voice search button with animated state feedback.
class VoiceSearchButton extends StatefulWidget {
  final ISpeechToTextService speechService;
  final SupportedLanguage selectedLanguage;
  final ValueChanged<String> onTranscriptReceived;
  final ValueChanged<SpeechTranscriptionResult>? onResultDetailed;
  final ValueChanged<VoiceError>? onError;
  final ValueChanged<VoiceState>? onStateChanged;
  final String label;
  final IconData idleIcon;
  final String tooltipPrefix;
  final Future<void> Function()? onBeforeStart;

  /// When true the control renders as a labelled, full-width "pill" (icon +
  /// product label) instead of a bare circular icon. Used to present the two
  /// voice modes as intentional product choices rather than dev A/B controls.
  final bool showLabel;

  const VoiceSearchButton({
    super.key,
    required this.speechService,
    required this.selectedLanguage,
    required this.onTranscriptReceived,
    this.onResultDetailed,
    this.onError,
    this.onStateChanged,
    this.label = 'Voice',
    this.idleIcon = Icons.mic_rounded,
    this.tooltipPrefix = 'Voice Search',
    this.onBeforeStart,
    this.showLabel = false,
  });

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  VoiceState _state = VoiceState.idle;
  String? _errorMessage;
  bool _isAwaitingStopResult = false;
  StreamSubscription<VoiceState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _state = widget.speechService.currentState;
    _stateSubscription = widget.speechService.stateStream.listen((state) {
      _handleStateChanged(state);
    });
  }

  @override
  void didUpdateWidget(VoiceSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speechService != widget.speechService) {
      _stateSubscription?.cancel();
      _state = widget.speechService.currentState;
      _stateSubscription = widget.speechService.stateStream.listen((state) {
        _handleStateChanged(state);
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleStateChanged(VoiceState state) {
    if (!mounted) return;
    setState(() {
      _state = state;
      if (state == VoiceState.listening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
    widget.onStateChanged?.call(state);
  }

  Future<void> _toggleListening() async {
    if (_state == VoiceState.listening) {
      // User tapped while listening -> stop & process
      _isAwaitingStopResult = true;
      final detailed = await widget.speechService.stopListeningDetailed();
      _isAwaitingStopResult = false;
      if (detailed != null &&
          (detailed.text.isNotEmpty || detailed.audioContext != null)) {
        if (detailed.text.isNotEmpty) {
          widget.onTranscriptReceived(detailed.text);
        }
        if (widget.onResultDetailed != null) {
          widget.onResultDetailed!(detailed);
        } else {
          detailed.disposeAudio();
        }
      } else if (detailed != null) {
        _showFriendlyVoiceError(
          const FriendlyResponseService().responseFor(
            FriendlyResponseCategory.emptyVoice,
          ),
        );
      }
      return;
    }

    if (_state == VoiceState.processing ||
        _state == VoiceState.requestingPermission) {
      // Busy
      return;
    }

    // Start listening
    _errorMessage = null;
    _isAwaitingStopResult = false;
    if (widget.onBeforeStart != null) {
      await widget.onBeforeStart!();
    }
    await widget.speechService.startListening(
      language: widget.selectedLanguage,
      onResult: (transcript, isFinal) {
        if (transcript.isNotEmpty) {
          // Native recognizers emit evolving partials. They belong in the same
          // editable field as typed input and never trigger search by themselves.
          widget.onTranscriptReceived(transcript);
        }
        if (isFinal && transcript.isNotEmpty && !_isAwaitingStopResult) {
          widget.onResultDetailed?.call(
            SpeechTranscriptionResult.textOnly(
              text: transcript,
              language: widget.selectedLanguage,
            ),
          );
        }
      },
      onStateChanged: _handleStateChanged,
      onError: (error) {
        _isAwaitingStopResult = false;
        if (!mounted) return;
        setState(() {
          _errorMessage = _friendlyVoiceError(error);
        });
        widget.onError?.call(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyVoiceError(error)),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  String _friendlyVoiceError(VoiceError error) {
    const responses = FriendlyResponseService();
    if (error.code == VoiceError.noSpeechDetected) {
      return responses.responseFor(FriendlyResponseCategory.emptyVoice);
    }
    if (error.code == VoiceError.timeout) {
      return responses.responseFor(FriendlyResponseCategory.timeout);
    }
    if (error.code == VoiceError.networkError) {
      return responses.responseFor(FriendlyResponseCategory.networkError);
    }
    return error.message;
  }

  void _showFriendlyVoiceError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget iconWidget;
    Color buttonColor;
    String tooltipText;

    switch (_state) {
      case VoiceState.listening:
        iconWidget = const Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: 20,
        );
        buttonColor = Colors.redAccent.shade400;
        tooltipText =
            '${widget.tooltipPrefix}: Listening (${widget.selectedLanguage.displayName})... Tap to stop';
        break;

      case VoiceState.processing:
        iconWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
        buttonColor = Colors.deepPurpleAccent;
        tooltipText = '${widget.tooltipPrefix}: Transcribing...';
        break;

      case VoiceState.requestingPermission:
        iconWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
        buttonColor = Colors.amber.shade700;
        tooltipText = 'Requesting microphone permission...';
        break;

      case VoiceState.error:
        iconWidget = const Icon(
          Icons.mic_off_rounded,
          color: Colors.white,
          size: 20,
        );
        buttonColor = Colors.red.shade600;
        tooltipText = _errorMessage ?? '${widget.tooltipPrefix} error. Tap to retry';
        break;

      case VoiceState.idle:
        iconWidget = Icon(
          widget.idleIcon,
          color: isDark ? Colors.white70 : theme.colorScheme.primary,
          size: 20,
        );
        buttonColor = isDark
            ? Colors.white12
            : theme.colorScheme.primary.withValues(alpha: 0.1);
        tooltipText =
            '${widget.tooltipPrefix} (${widget.selectedLanguage.displayName})';
        break;
    }

    // Product-facing state label used by the labelled pill and screen readers.
    final String stateLabel;
    switch (_state) {
      case VoiceState.listening:
        stateLabel = 'Listening…';
        break;
      case VoiceState.processing:
        stateLabel = 'Transcribing…';
        break;
      case VoiceState.requestingPermission:
        stateLabel = 'Requesting mic…';
        break;
      case VoiceState.error:
        stateLabel = 'Tap to retry';
        break;
      case VoiceState.idle:
        stateLabel = widget.label;
        break;
    }

    // Active (recording) is signalled by icon + label + motion, never colour
    // alone, for accessibility.
    final bool isActive = _state == VoiceState.listening;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isActive ? _pulseAnimation.value : 1.0;

        if (widget.showLabel) {
          final Color pillFg = _state == VoiceState.idle
              ? (isDark ? Colors.white : theme.colorScheme.primary)
              : Colors.white;
          return Semantics(
            button: true,
            label: '${widget.tooltipPrefix}. $stateLabel',
            child: Tooltip(
              message: tooltipText,
              child: Material(
                color: buttonColor,
                borderRadius: BorderRadius.circular(24),
                elevation: isActive ? 3 : 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _toggleListening,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(scale: scale, child: iconWidget),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pillFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Transform.scale(
          scale: scale,
          child: Semantics(
            button: true,
            label: '${widget.tooltipPrefix}. $stateLabel',
            child: Tooltip(
              message: tooltipText,
              child: Material(
                color: buttonColor,
                shape: const CircleBorder(),
                elevation: isActive ? 4 : 0,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleListening,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: iconWidget,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
