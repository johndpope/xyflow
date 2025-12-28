// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Web implementation of drop zone using dart:html
class WebDropZone extends StatefulWidget {
  const WebDropZone({
    super.key,
    required this.child,
    this.onDrop,
    this.onDropWithUrl,
    this.onDragEnter,
    this.onDragLeave,
  });

  final Widget child;
  final void Function(Uint8List bytes, String name)? onDrop;
  final void Function(String blobUrl, String name)? onDropWithUrl;
  final VoidCallback? onDragEnter;
  final VoidCallback? onDragLeave;

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  late html.DivElement _dropZone;
  late String _viewType;
  bool _registered = false;

  // Document-level listeners for detecting when drag starts/ends
  html.EventListener? _docDragEnterListener;
  html.EventListener? _docDragLeaveListener;
  html.EventListener? _docDropListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'drop-zone-${DateTime.now().millisecondsSinceEpoch}';
    _setupDropZone();
    _setupDocumentListeners();
  }

  @override
  void dispose() {
    _removeDocumentListeners();
    super.dispose();
  }

  void _setupDocumentListeners() {
    // When drag enters the document, enable pointer events on our drop zone
    _docDragEnterListener = (html.Event e) {
      _dropZone.style.pointerEvents = 'auto';
    };

    // When drag leaves document or drop happens, disable pointer events
    _docDragLeaveListener = (html.Event e) {
      // Only disable if leaving the document entirely
      final mouseEvent = e as html.MouseEvent;
      if (mouseEvent.relatedTarget == null) {
        _dropZone.style.pointerEvents = 'none';
      }
    };

    _docDropListener = (html.Event e) {
      _dropZone.style.pointerEvents = 'none';
    };

    html.document.addEventListener('dragenter', _docDragEnterListener);
    html.document.addEventListener('dragleave', _docDragLeaveListener);
    html.document.addEventListener('drop', _docDropListener);
  }

  void _removeDocumentListeners() {
    if (_docDragEnterListener != null) {
      html.document.removeEventListener('dragenter', _docDragEnterListener);
    }
    if (_docDragLeaveListener != null) {
      html.document.removeEventListener('dragleave', _docDragLeaveListener);
    }
    if (_docDropListener != null) {
      html.document.removeEventListener('drop', _docDropListener);
    }
  }

  void _setupDropZone() {
    _dropZone = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      // Start with pointer-events: none so clicks pass through
      // Will be set to 'auto' when drag enters document
      ..style.pointerEvents = 'none';

    _dropZone.onDragOver.listen((event) {
      event.preventDefault();
      event.stopPropagation();
    });

    _dropZone.onDragEnter.listen((event) {
      event.preventDefault();
      event.stopPropagation();
      widget.onDragEnter?.call();
    });

    _dropZone.onDragLeave.listen((event) {
      event.preventDefault();
      event.stopPropagation();
      widget.onDragLeave?.call();
    });

    _dropZone.onDrop.listen((event) async {
      event.preventDefault();
      event.stopPropagation();
      widget.onDragLeave?.call();

      // Disable pointer events after drop
      _dropZone.style.pointerEvents = 'none';

      final files = event.dataTransfer?.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];

        // If onDropWithUrl is provided, create a blob URL directly
        if (widget.onDropWithUrl != null) {
          final blobUrl = html.Url.createObjectUrlFromBlob(file);
          widget.onDropWithUrl?.call(blobUrl, file.name);
          return;
        }

        // Otherwise read as bytes
        final reader = html.FileReader();

        reader.onLoadEnd.listen((event) {
          final result = reader.result;
          if (result is Uint8List) {
            widget.onDrop?.call(result, file.name);
          }
        });

        reader.readAsArrayBuffer(file);
      }
    });

    // Register the platform view factory only once
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _dropZone,
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: HtmlElementView(viewType: _viewType),
          ),
        ),
      ],
    );
  }
}
