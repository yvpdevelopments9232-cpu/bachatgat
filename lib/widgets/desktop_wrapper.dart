import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopWrapper extends StatefulWidget {
  final Widget child;
  final double minWidth;

  const DesktopWrapper({
    super.key,
    required this.child,
    this.minWidth = 1000,
  });

  @override
  State<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends State<DesktopWrapper> {
  late final TransformationController _transformationController;
  double _currentScale = 1.0;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() => _currentScale = scale);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomTo(double targetScale) {
    HapticFeedback.selectionClick();
    _transformationController.value = Matrix4.identity()..scale(targetScale);
  }

  void _zoomIn() {
    final newScale = (_currentScale + 0.15).clamp(0.30, 2.5);
    _zoomTo(newScale);
  }

  void _zoomOut() {
    final newScale = (_currentScale - 0.15).clamp(0.30, 2.5);
    _zoomTo(newScale);
  }

  void _zoomFit(double screenWidth) {
    _zoomTo(1.0);
  }

  void _zoomReset() {
    _zoomTo(1.0);
  }

  void _toggleDoubleTap(double screenWidth) {
    if ((_currentScale - 1.0).abs() < 0.08) {
      _zoomTo(1.5);
    } else {
      _zoomTo(1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // On desktop screens, render normally without any zoom wrappers
    if (screenWidth >= widget.minWidth) {
      return widget.child;
    }

    final bool isZoomed = (_currentScale - 1.0).abs() > 0.02;

    return Stack(
      children: [
        // Two-finger pinch-to-zoom & Pan container
        GestureDetector(
          onDoubleTap: () => _toggleDoubleTap(screenWidth),
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.60,
            maxScale: 2.5,
            scaleEnabled: true,
            panEnabled: isZoomed,
            constrained: true,
            boundaryMargin: isZoomed ? const EdgeInsets.all(40) : EdgeInsets.zero,
            child: widget.child,
          ),
        ),

        // Floating Mobile Zoom Controls Toolbar
        Positioned(
          bottom: 24,
          right: 16,
          child: SafeArea(
            child: _isCollapsed
                ? Material(
                    elevation: 6,
                    shape: const CircleBorder(),
                    color: Colors.black87,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _isCollapsed = false),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  )
                : Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.black.withOpacity(0.85),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Zoom Out Button
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 20),
                            tooltip: 'Zoom Out (झूम कमी करा)',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomOut,
                          ),
                          const SizedBox(width: 4),

                          // Zoom percentage (tap to toggle fit/full)
                          GestureDetector(
                            onTap: () => _toggleDoubleTap(screenWidth),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_currentScale * 100).round()}%',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Zoom In Button
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                            tooltip: 'Zoom In (झूम वाढवा)',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomIn,
                          ),

                          // Divider
                          Container(height: 16, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),

                          // Fit to screen button
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _zoomFit(screenWidth),
                            child: const Text('Fit', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),

                          // 100% Reset button
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _zoomReset,
                            child: const Text('100%', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),

                          // Minimize/Hide button
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                            tooltip: 'Hide Controls',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _isCollapsed = true),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
