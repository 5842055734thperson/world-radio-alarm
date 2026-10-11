import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import 'favorites_page.dart';
import 'graph_page.dart';

/// The Discover tab: the related-stations tree and the user's library.
class DiscoverHub extends StatefulWidget {
  const DiscoverHub({super.key});

  @override
  State<DiscoverHub> createState() => _DiscoverHubState();
}

class _DiscoverHubState extends State<DiscoverHub> {
  int _view = 0; // 0 = tree, 1 = library

  @override
  void initState() {
    super.initState();
    // "Discover similar stations" should land on the tree.
    discoverSeed.addListener(_showTree);
  }

  @override
  void dispose() {
    discoverSeed.removeListener(_showTree);
    super.dispose();
  }

  void _showTree() {
    if (_view != 0) setState(() => _view = 0);
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, String text) => Expanded(
          child: BrutBox(
            inverted: _view == i,
            onTap: () => setState(() => _view = i),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('DISCOVER', style: display(context, size: 34)),
              const SizedBox(width: 16),
              tab(0, 'TREE'),
              const SizedBox(width: 6),
              tab(1, 'LIBRARY'),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view,
            children: const [GraphPage(), FavoritesPage()],
          ),
        ),
      ],
    );
  }
}
