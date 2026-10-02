import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'search_providers.dart';
import 'search_results_view.dart';
import '../../core/widgets/nav/back_navigation.dart';

/// `/search?q=` — every match, grouped. On a phone this is where the
/// search icon leads; on a wide screen, where Enter in the top bar's
/// field goes for the full list.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final results = ref.watch(searchResultsProvider(query));
    final loading = ref.watch(searchCorpusProvider).isLoading;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('search.field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          style: AppTheme.bodyLg.copyWith(color: context.palette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search courses, topics, lessons',
            hintStyle: AppTheme.bodyLg.copyWith(
              color: context.palette.textSecondary,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_controller.clear),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: CircularProgressIndicator(),
                  ),
                )
              : results.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: SearchEmptyMessage(query: query),
                )
              : SearchResultsView(
                  query: query,
                  results: results,
                  onOpen: (item) => context.push(item.path),
                ),
        ),
      ),
    );
  }
}
