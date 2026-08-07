import 'dart:async';

import 'package:flutter/material.dart';

/// In-memory scroll offsets keyed by storage id for the current process.
///
/// Survives route dispose/rebuild (e.g. Settings pop + push) where Flutter's
/// per-route page storage would not.
@visibleForTesting
class ScrollOffsetMemory {
  ScrollOffsetMemory._();

  static final Map<String, double> _offsets = <String, double>{};

  static double read(String storageId) => _offsets[storageId] ?? 0;

  static void write(String storageId, double offset) {
    _offsets[storageId] = offset;
  }

  static void clear() => _offsets.clear();
}

enum _ScrollBodyKind { list, view, slivers }

/// Scrollable scaffold body that restores offset across rebuilds / navigation
/// and optionally shows jump-to-top / jump-to-bottom controls.
class RestorableScrollBody extends StatefulWidget {
  /// List-style body (`ListView.builder` of [children]).
  ///
  /// Children are mounted lazily; prefer [RestorableScrollBody.slivers] when
  /// the parent would otherwise allocate a huge widget list every build.
  const RestorableScrollBody.list({
    required this.storageId,
    required this.children,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.showJumpControls = false,
    this.edgeThreshold = 48,
  }) : child = null,
       slivers = null,
       _kind = _ScrollBodyKind.list;

  /// Column-style body (`SingleChildScrollView` wrapping [child]).
  const RestorableScrollBody.view({
    required this.storageId,
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.showJumpControls = false,
    this.edgeThreshold = 48,
  }) : children = null,
       slivers = null,
       _kind = _ScrollBodyKind.view;

  /// Custom scroll view; caller owns padding via [SliverPadding] / etc.
  const RestorableScrollBody.slivers({
    required this.storageId,
    required this.slivers,
    super.key,
    this.showJumpControls = false,
    this.edgeThreshold = 48,
  }) : child = null,
       children = null,
       padding = EdgeInsets.zero,
       _kind = _ScrollBodyKind.slivers;

  /// Stable key for page storage and [ScrollOffsetMemory].
  final String storageId;

  final EdgeInsetsGeometry padding;
  final bool showJumpControls;
  final double edgeThreshold;
  final List<Widget>? children;
  final Widget? child;
  final List<Widget>? slivers;
  final _ScrollBodyKind _kind;

  @override
  State<RestorableScrollBody> createState() => _RestorableScrollBodyState();
}

class _RestorableScrollBodyState extends State<RestorableScrollBody> {
  static const Duration _jumpDuration = Duration(milliseconds: 280);
  static const Curve _jumpCurve = Curves.easeOutCubic;

  late final ScrollController _controller;
  bool _showTop = false;
  bool _showBottom = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: ScrollOffsetMemory.read(widget.storageId),
    );
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncJumpVisibility());
  }

  @override
  void didUpdateWidget(covariant RestorableScrollBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageId == widget.storageId) return;
    _persist(oldWidget.storageId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final double target = ScrollOffsetMemory.read(widget.storageId).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      );
      if ((_controller.offset - target).abs() > 0.5) {
        _controller.jumpTo(target);
      }
      _syncJumpVisibility();
    });
  }

  @override
  void dispose() {
    _persist(widget.storageId);
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _persist(String storageId) {
    if (_controller.hasClients) {
      ScrollOffsetMemory.write(storageId, _controller.offset);
    }
  }

  void _onScroll() {
    _persist(widget.storageId);
    _syncJumpVisibility();
  }

  void _syncJumpVisibility() {
    if (!widget.showJumpControls || !mounted) return;
    if (!_controller.hasClients) {
      if (_showTop || _showBottom) {
        setState(() {
          _showTop = false;
          _showBottom = false;
        });
      }
      return;
    }

    final ScrollPosition position = _controller.position;
    final double max = position.maxScrollExtent;
    final bool canScroll = max > widget.edgeThreshold;
    final double offset = _controller.offset;
    final bool showTop = canScroll && offset > widget.edgeThreshold;
    final bool showBottom = canScroll && offset < max - widget.edgeThreshold;
    if (showTop == _showTop && showBottom == _showBottom) return;
    setState(() {
      _showTop = showTop;
      _showBottom = showBottom;
    });
  }

  Future<void> _animateTo(double offset, {required bool stickToEnd}) async {
    if (!_controller.hasClients) return;

    await _controller.animateTo(
      stickToEnd ? _controller.position.maxScrollExtent : offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: _jumpDuration,
      curve: _jumpCurve,
    );

    // Lazy lists may grow [maxScrollExtent] as newly revealed children layout.
    if (stickToEnd) {
      _snapToEnd();
    }
  }

  /// Jump remaining distance after an animated end-jump; rechecks a few frames
  /// as estimated extents settle. Uses post-frame callbacks (not endOfFrame)
  /// so widget tests cannot stall waiting on an unscheduled frame.
  void _snapToEnd({int remaining = 8}) {
    if (!mounted || !_controller.hasClients || remaining <= 0) return;
    final double max = _controller.position.maxScrollExtent;
    if ((_controller.offset - max).abs() < 1) return;
    _controller.jumpTo(max);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapToEnd(remaining: remaining - 1);
    });
  }

  Widget _buildScrollable() {
    final Key storageKey = PageStorageKey<String>(widget.storageId);
    switch (widget._kind) {
      case _ScrollBodyKind.list:
        final List<Widget> children = widget.children!;
        return ListView.builder(
          key: storageKey,
          controller: _controller,
          padding: widget.padding,
          itemCount: children.length,
          itemBuilder: (BuildContext context, int index) => children[index],
        );
      case _ScrollBodyKind.view:
        return SingleChildScrollView(
          key: storageKey,
          controller: _controller,
          padding: widget.padding,
          child: widget.child,
        );
      case _ScrollBodyKind.slivers:
        return CustomScrollView(
          key: storageKey,
          controller: _controller,
          slivers: widget.slivers!,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget scrollable = NotificationListener<ScrollMetricsNotification>(
      onNotification: (ScrollMetricsNotification notification) {
        _syncJumpVisibility();
        return false;
      },
      child: _buildScrollable(),
    );

    if (!widget.showJumpControls) return scrollable;

    return Stack(
      children: <Widget>[
        scrollable,
        Positioned(
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_showTop)
                  _JumpButton(
                    tooltip: 'Scroll to top',
                    icon: Icons.keyboard_arrow_up,
                    onPressed: () => unawaited(
                      _animateTo(0, stickToEnd: false),
                    ),
                  ),
                if (_showTop && _showBottom) const SizedBox(height: 8),
                if (_showBottom)
                  _JumpButton(
                    tooltip: 'Scroll to bottom',
                    icon: Icons.keyboard_arrow_down,
                    onPressed: () {
                      if (!_controller.hasClients) return;
                      unawaited(
                        _animateTo(
                          _controller.position.maxScrollExtent,
                          stickToEnd: true,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
