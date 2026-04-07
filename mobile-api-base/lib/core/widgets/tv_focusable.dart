import 'package:flutter/material.dart';

class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onFocusChanged,
    this.focusNode,
    this.onKeyEvent,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding = EdgeInsets.zero,
    this.focusedBorderColor = const Color(0xFFFFD15C),
    this.focusedBackgroundColor,
    this.autofocus = false,
    this.enabled = true,
    this.scrollOnFocus = true,
    this.focusScale = 1.03,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color focusedBorderColor;
  final Color? focusedBackgroundColor;
  final bool autofocus;
  final bool enabled;
  final bool scrollOnFocus;
  final double focusScale;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (!mounted) return;
    setState(() {
      _focused = focused;
    });
    widget.onFocusChanged?.call(focused);

    if (focused && widget.scrollOnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollOnFocus) return;
        final scrollable = Scrollable.maybeOf(context);
        if (scrollable == null) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.18,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = widget.enabled && widget.onTap != null;
    final fillColor = widget.focusedBackgroundColor;
    final borderColor = _focused
        ? widget.focusedBorderColor
        : Colors.white.withValues(alpha: 0.10);

    return Focus(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      canRequestFocus: canInteract,
      onFocusChange: _handleFocusChange,
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedScale(
        scale: _focused ? widget.focusScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: fillColor ??
                (_focused ? Colors.white.withValues(alpha: 0.06) : null),
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: borderColor,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.focusedBorderColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
