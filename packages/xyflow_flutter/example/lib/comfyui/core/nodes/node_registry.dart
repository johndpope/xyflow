/// Node registry - manages all available node types.
library;

import 'node_definition.dart';

/// Registry of all available node definitions.
///
/// Loaded from ComfyUI backend via the object_info API endpoint.
class NodeRegistry {
  final Map<String, NodeDefinition> _definitions = {};
  final Map<String, List<String>> _categoryNodes = {};

  /// All registered node names.
  Iterable<String> get nodeNames => _definitions.keys;

  /// All registered definitions.
  Iterable<NodeDefinition> get definitions => _definitions.values;

  /// All category paths.
  List<String> get categories => _categoryNodes.keys.toList()..sort();

  /// Number of registered nodes.
  int get length => _definitions.length;

  /// Register a node definition.
  void register(NodeDefinition definition) {
    _definitions[definition.name] = definition;

    // Update category index
    _categoryNodes.putIfAbsent(definition.category, () => []);
    _categoryNodes[definition.category]!.add(definition.name);
  }

  /// Register multiple definitions.
  void registerAll(Iterable<NodeDefinition> definitions) {
    for (final def in definitions) {
      register(def);
    }
  }

  /// Get a definition by name.
  NodeDefinition? get(String name) => _definitions[name];

  /// Check if a node type exists.
  bool has(String name) => _definitions.containsKey(name);

  /// Get all nodes in a category.
  List<NodeDefinition> getByCategory(String category) {
    final names = _categoryNodes[category] ?? [];
    return names.map((n) => _definitions[n]!).toList();
  }

  /// Get all nodes matching a category prefix.
  List<NodeDefinition> getByCategoryPrefix(String prefix) {
    return definitions
        .where((d) => d.category.startsWith(prefix))
        .toList();
  }

  /// Search nodes by name or display name.
  List<NodeDefinition> search(String query) {
    if (query.isEmpty) return definitions.toList();

    final lowerQuery = query.toLowerCase();
    final results = <NodeDefinition>[];
    final scores = <NodeDefinition, int>{};

    for (final def in definitions) {
      final nameLower = def.name.toLowerCase();
      final displayLower = def.displayName.toLowerCase();

      // Exact match gets highest score
      if (nameLower == lowerQuery || displayLower == lowerQuery) {
        scores[def] = 100;
        results.add(def);
        continue;
      }

      // Starts with gets high score
      if (nameLower.startsWith(lowerQuery) || displayLower.startsWith(lowerQuery)) {
        scores[def] = 80;
        results.add(def);
        continue;
      }

      // Contains gets medium score
      if (nameLower.contains(lowerQuery) || displayLower.contains(lowerQuery)) {
        scores[def] = 50;
        results.add(def);
        continue;
      }

      // Fuzzy match: all query chars in order
      if (_fuzzyMatch(nameLower, lowerQuery) || _fuzzyMatch(displayLower, lowerQuery)) {
        scores[def] = 30;
        results.add(def);
      }
    }

    // Sort by score descending, then alphabetically
    results.sort((a, b) {
      final scoreCompare = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
      if (scoreCompare != 0) return scoreCompare;
      return a.displayName.compareTo(b.displayName);
    });

    return results;
  }

  /// Simple fuzzy match: all query chars appear in order.
  bool _fuzzyMatch(String text, String query) {
    var queryIndex = 0;
    for (var i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex == query.length;
  }

  /// Get a category tree structure.
  CategoryTree getCategoryTree() {
    final root = CategoryTree(name: 'root', path: '');

    for (final category in categories) {
      final parts = category.split('/');
      var current = root;

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final path = parts.sublist(0, i + 1).join('/');

        var child = current.children.firstWhere(
          (c) => c.name == part,
          orElse: () {
            final newChild = CategoryTree(name: part, path: path);
            current.children.add(newChild);
            return newChild;
          },
        );
        current = child;
      }

      // Add nodes to the leaf category
      final nodes = _categoryNodes[category] ?? [];
      for (final nodeName in nodes) {
        final def = _definitions[nodeName];
        if (def != null) {
          current.nodes.add(def);
        }
      }
    }

    return root;
  }

  /// Load from ComfyUI object_info API response.
  void loadFromApi(Map<String, dynamic> objectInfo) {
    objectInfo.forEach((name, data) {
      if (data is Map<String, dynamic>) {
        try {
          final def = NodeDefinition.fromApi(name, data);
          register(def);
        } catch (e) {
          // Skip invalid definitions
          print('Failed to parse node $name: $e');
        }
      }
    });
  }

  /// Clear all registered nodes.
  void clear() {
    _definitions.clear();
    _categoryNodes.clear();
  }

  @override
  String toString() => 'NodeRegistry(${_definitions.length} nodes)';
}

/// Tree structure for categories.
class CategoryTree {
  final String name;
  final String path;
  final List<CategoryTree> children = [];
  final List<NodeDefinition> nodes = [];

  CategoryTree({required this.name, required this.path});

  /// Whether this is a leaf category (has no children).
  bool get isLeaf => children.isEmpty;

  /// Total nodes in this category and all children.
  int get totalNodes {
    var count = nodes.length;
    for (final child in children) {
      count += child.totalNodes;
    }
    return count;
  }

  /// Flatten all nodes in this subtree.
  List<NodeDefinition> get allNodes {
    final result = <NodeDefinition>[...nodes];
    for (final child in children) {
      result.addAll(child.allNodes);
    }
    return result;
  }
}
