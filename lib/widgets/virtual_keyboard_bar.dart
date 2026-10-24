import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VirtualKeyboardBar extends StatefulWidget {
  final Function(List<int>) onSendBytes;
  final Function(String) onSendString;
  final VoidCallback onDismissKeyboard;

  const VirtualKeyboardBar({
    super.key,
    required this.onSendBytes,
    required this.onSendString,
    required this.onDismissKeyboard,
  });

  @override
  State<VirtualKeyboardBar> createState() => _VirtualKeyboardBarState();
}

class _VirtualKeyboardBarState extends State<VirtualKeyboardBar> {
  bool _ctrlActive = false;
  bool _altActive = false;

  void _sendKey(String char) {
    HapticFeedback.lightImpact();
    if (_ctrlActive) {
      final code = char.toUpperCase().codeUnitAt(0);
      if (code >= 64 && code <= 95) {
        widget.onSendBytes([code - 64]);
      } else {
        widget.onSendString(char);
      }
      setState(() => _ctrlActive = false);
      return;
    }

    if (_altActive) {
      widget.onSendBytes([27, char.codeUnitAt(0)]);
      setState(() => _altActive = false);
      return;
    }

    widget.onSendString(char);
  }

  void _sendEscapeSequence(List<int> bytes) {
    HapticFeedback.lightImpact();
    widget.onSendBytes(bytes);
    if (_ctrlActive) setState(() => _ctrlActive = false);
    if (_altActive) setState(() => _altActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildKeyBtn({
      required Widget child,
      required VoidCallback onTap,
      bool isActive = false,
      Color? activeColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        child: Material(
          color: isActive
              ? (activeColor ?? colorScheme.primary)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 42, minHeight: 36),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: isActive
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          // ESC
          buildKeyBtn(
            child: const Text('ESC'),
            onTap: () => _sendEscapeSequence([27]),
          ),
          // TAB
          buildKeyBtn(
            child: const Text('TAB'),
            onTap: () => _sendEscapeSequence([9]),
          ),
          // CTRL Toggle
          buildKeyBtn(
            child: const Text('CTRL'),
            isActive: _ctrlActive,
            activeColor: colorScheme.primary,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _ctrlActive = !_ctrlActive);
            },
          ),
          // ALT Toggle
          buildKeyBtn(
            child: const Text('ALT'),
            isActive: _altActive,
            activeColor: colorScheme.secondary,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _altActive = !_altActive);
            },
          ),
          // Common Quick Shortcuts
          buildKeyBtn(
            child: const Text('Ctrl+C'),
            onTap: () => _sendEscapeSequence([3]), // ETX
          ),
          buildKeyBtn(
            child: const Text('Ctrl+D'),
            onTap: () => _sendEscapeSequence([4]), // EOT
          ),
          buildKeyBtn(
            child: const Text('Ctrl+Z'),
            onTap: () => _sendEscapeSequence([26]), // SUB
          ),
          buildKeyBtn(
            child: const Text('Ctrl+L'),
            onTap: () => _sendEscapeSequence([12]), // FF (Clear screen)
          ),
          // Arrow Keys
          buildKeyBtn(
            child: const Icon(Icons.arrow_upward, size: 16),
            onTap: () => _sendEscapeSequence([27, 91, 65]), // Up: \e[A
          ),
          buildKeyBtn(
            child: const Icon(Icons.arrow_downward, size: 16),
            onTap: () => _sendEscapeSequence([27, 91, 66]), // Down: \e[B
          ),
          buildKeyBtn(
            child: const Icon(Icons.arrow_back, size: 16),
            onTap: () => _sendEscapeSequence([27, 91, 68]), // Left: \e[D
          ),
          buildKeyBtn(
            child: const Icon(Icons.arrow_forward, size: 16),
            onTap: () => _sendEscapeSequence([27, 91, 67]), // Right: \e[C
          ),
          // Pipe and symbols
          buildKeyBtn(child: const Text('|'), onTap: () => _sendKey('|')),
          buildKeyBtn(child: const Text('~'), onTap: () => _sendKey('~')),
          buildKeyBtn(child: const Text('/'), onTap: () => _sendKey('/')),
          buildKeyBtn(child: const Text('-'), onTap: () => _sendKey('-')),
          buildKeyBtn(child: const Text('_'), onTap: () => _sendKey('_')),
          buildKeyBtn(child: const Text(':'), onTap: () => _sendKey(':')),
          buildKeyBtn(child: const Text('\$'), onTap: () => _sendKey('\$')),
          buildKeyBtn(child: const Text(';'), onTap: () => _sendKey(';')),
          // Hide keyboard button
          buildKeyBtn(
            child: const Icon(Icons.keyboard_hide, size: 16),
            onTap: widget.onDismissKeyboard,
          ),
        ],
      ),
    );
  }
}
