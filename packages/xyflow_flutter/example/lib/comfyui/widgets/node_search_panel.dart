/// Node Search Panel - Search and browse node types for ComfyUI.
///
/// Features:
/// - Fuzzy search with ranking
/// - Category tree navigation
/// - Recent nodes section
/// - Keyboard navigation
/// - Double-click/enter to add node
/// - Display node descriptions
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/nodes/node_definition.dart';
import '../core/nodes/node_registry.dart' show NodeRegistry, CategoryTree;

/// Callback when a node type is selected.
typedef OnNodeSelected = void Function(NodeDefinition definition, Offset? position);

/// Panel for searching and browsing node types.
class NodeSearchPanel extends StatefulWidget {
  /// Creates a node search panel.
  const NodeSearchPanel({
    super.key,
    required this.registry,
    required this.onNodeSelected,
    this.recentNodes = const [],
    this.maxRecentNodes = 5,
    this.position,
    this.width = 300,
    this.maxHeight = 400,
    this.autofocus = true,
    this.onClose,
  });

  /// The node registry to search.
  final NodeRegistry registry;

  /// Callback when a node is selected.
  final OnNodeSelected onNodeSelected;

  /// List of recently used node types.
  final List<String> recentNodes;

  /// Maximum number of recent nodes to show.
  final int maxRecentNodes;

  /// Position where the panel was opened (for node placement).
  final Offset? position;

  /// Panel width.
  final double width;

  /// Maximum panel height.
  final double maxHeight;

  /// Whether to autofocus the search field.
  final bool autofocus;

  /// Callback when panel is closed.
  final VoidCallback? onClose;

  @override
  State<NodeSearchPanel> createState() => _NodeSearchPanelState();
}

class _NodeSearchPanelState extends State<NodeSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<NodeDefinition> _searchResults = [];
  int _selectedIndex = -1;
  bool _showCategories = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _updateSearchResults();

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _updateSearchResults();
  }

  void _updateSearchResults() {
    final query = _searchController.text.trim();

    setState(() {
      if (query.isEmpty && _selectedCategory == null) {
        _searchResults = [];
        _showCategories = true;
      } else if (_selectedCategory != null) {
        _searchResults = widget.registry.getByCategory(_selectedCategory!);
        _showCategories = false;
      } else {
        _searchResults = widget.registry.search(query);
        _showCategories = false;
      }
      _selectedIndex = _searchResults.isNotEmpty ? 0 : -1;
    });
  }

  void _selectNode(NodeDefinition def) {
    widget.onNodeSelected(def, widget.position);
    widget.onClose?.call();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < _searchResults.length) {
        _selectNode(_searchResults[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectedCategory != null) {
        setState(() {
          _selectedCategory = null;
          _updateSearchResults();
        });
      } else if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      } else {
        widget.onClose?.call();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _searchController.text.isEmpty &&
        _selectedCategory != null) {
      setState(() {
        _selectedCategory = null;
        _updateSearchResults();
      });
    }
  }

  void _moveSelection(int delta) {
    if (_searchResults.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _searchResults.length - 1);
    });

    // Scroll to selected item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex >= 0 && _scrollController.hasClients) {
        final itemHeight = 56.0;
        final targetScroll = (_selectedIndex * itemHeight) - 100;
        if (targetScroll > _scrollController.offset + 200 ||
            targetScroll < _scrollController.offset - 100) {
          _scrollController.animateTo(
            targetScroll.clamp(0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Container(
        width: widget.width,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black54),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchField(),
            if (_selectedCategory != null) _buildBreadcrumb(),
            Flexible(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black38)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search nodes...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500], size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.requestFocus();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        border: Border(bottom: BorderSide(color: Colors.black38)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = null;
                _updateSearchResults();
              });
            },
            child: const Text(
              'Categories',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
          Expanded(
            child: Text(
              _selectedCategory ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_showCategories && _searchController.text.isEmpty) {
      return _buildCategoryView();
    }
    return _buildSearchResults();
  }

  Widget _buildCategoryView() {
    final tree = widget.registry.getCategoryTree();
    final recentDefs = widget.recentNodes
        .take(widget.maxRecentNodes)
        .map((name) => widget.registry.get(name))
        .whereType<NodeDefinition>()
        .toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // Recent nodes section
        if (recentDefs.isNotEmpty) ...[
          _buildSectionHeader('Recent'),
          ...recentDefs.map((def) => _buildNodeItem(def, -1)),
          const Divider(color: Colors.black38, height: 16),
        ],
        // Categories
        _buildSectionHeader('Categories'),
        ...tree.children.map((child) => _buildCategoryItem(child)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryTree category) {
    final nodeCount = category.totalNodes;
    final color = NodeCategory.getColor(category.name);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category.path;
          _updateSearchResults();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '$nodeCount',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, color: Colors.grey[600], size: 48),
              const SizedBox(height: 12),
              Text(
                'No nodes found',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildNodeItem(_searchResults[index], index);
      },
    );
  }

  Widget _buildNodeItem(NodeDefinition def, int index) {
    final isSelected = index == _selectedIndex;
    final color = def.color ?? NodeCategory.getColor(def.category);

    return InkWell(
      onTap: () => _selectNode(def),
      onDoubleTap: () => _selectNode(def),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : null,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (def.description != null && def.description!.isNotEmpty)
                    Text(
                      def.description!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              def.category,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating node search panel that can be positioned anywhere.
class FloatingNodeSearchPanel extends StatelessWidget {
  /// Creates a floating node search panel.
  const FloatingNodeSearchPanel({
    super.key,
    required this.registry,
    required this.onNodeSelected,
    required this.position,
    this.recentNodes = const [],
    this.onClose,
  });

  /// The node registry to search.
  final NodeRegistry registry;

  /// Callback when a node is selected.
  final OnNodeSelected onNodeSelected;

  /// Position of the panel.
  final Offset position;

  /// List of recently used node types.
  final List<String> recentNodes;

  /// Callback when panel is closed.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop to close panel
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Panel
        Positioned(
          left: position.dx,
          top: position.dy,
          child: NodeSearchPanel(
            registry: registry,
            onNodeSelected: onNodeSelected,
            recentNodes: recentNodes,
            position: position,
            onClose: onClose,
          ),
        ),
      ],
    );
  }
}

/// Shows a node search panel as a modal.
Future<NodeDefinition?> showNodeSearchPanel({
  required BuildContext context,
  required NodeRegistry registry,
  Offset? position,
  List<String> recentNodes = const [],
}) async {
  NodeDefinition? result;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) {
      return Center(
        child: NodeSearchPanel(
          registry: registry,
          onNodeSelected: (def, _) {
            result = def;
            Navigator.of(context).pop();
          },
          recentNodes: recentNodes,
          position: position,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    },
  );

  return result;
}
