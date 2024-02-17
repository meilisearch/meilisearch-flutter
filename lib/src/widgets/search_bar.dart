import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';
import 'package:rxdart/rxdart.dart';

class DefaultMeiliSearchItemWidget<T extends Object> extends StatelessWidget {
  const DefaultMeiliSearchItemWidget({
    super.key,
    required this.item,
    required this.displayAttribute,
    this.itemToString,
    this.preTag,
    this.postTag,
    this.highlightedStyle,
    this.onTap,
  });
  final MeiliDocumentContainer<T> item;
  final VoidCallback? onTap;
  final String Function(T item)? itemToString;
  final String? displayAttribute;
  final TextStyle? highlightedStyle;

  final String? preTag;
  final String? postTag;
  @override
  Widget build(BuildContext context) {
    final postTag = this.postTag;
    final preTag = this.preTag;
    final defaultStyle = DefaultTextStyle.of(context).style;
    //try to get formatted text, then fallback to displayAttribute
    final String itemString = displayAttribute == null
        ? itemToString?.call(item.parsed) ?? item.parsed.toString()
        : item.formatted?[displayAttribute] ?? item.src[displayAttribute];
    return ListTile(
      onTap: onTap,
      title: postTag == null || preTag == null
          ? Text(itemString)
          : Text.rich(textSpanFromHighligtableString(
              itemString,
              preTag: preTag,
              postTag: postTag,
              highlightedStyle: highlightedStyle ??
                  defaultStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
              normalStyle: defaultStyle,
            )),
    );
  }
}

// see examples here
// https://github.com/flutter/flutter/tree/master/examples/api/lib/material/search_anchor
class MeiliSearchBar<T extends Object> extends StatefulWidget {
  MeiliSearchBar({
    super.key,
    required this.mapper,
    required this.client,
    this.itemToString,
    required IndexSearchQuery Function(String textFilter) getQuery,
    this.barHintText,
    this.searchController,
    this.debounce = const Duration(milliseconds: 500),
    this.totalDocumentLimit,
    this.itemBuilder,
    this.displayAttribute,
    this.preloadCount,
  }) : getQuery = ((textFilter) => MultiSearchQuery(
              queries: [
                getQuery(textFilter),
              ],
            ));

  const MeiliSearchBar.multiQuery({
    super.key,
    required this.client,
    required this.mapper,
    required this.getQuery,
    this.itemToString,
    this.barHintText,
    this.searchController,
    this.debounce = const Duration(milliseconds: 500),
    this.totalDocumentLimit,
    this.itemBuilder,
    this.displayAttribute,
    this.preloadCount,
  });

  final MeiliSearchClient client;

  final MultiSearchQuery Function(String textFilter) getQuery;

  final Widget Function(
    BuildContext context,
    MeiliDocumentContainer<T> item,
  )? itemBuilder;

  final int? totalDocumentLimit;

  /// how many items should be remaining to start fetching more data
  final int? preloadCount;
  final String? barHintText;
  final SearchController? searchController;
  final MeilisearchDocumentMapper<Map<String, dynamic>, T> mapper;
  final String Function(T item)? itemToString;
  final String? displayAttribute;
  final Duration? debounce;
  @override
  State<MeiliSearchBar<T>> createState() => _MeiliSearchBarState<T>();
}

class _MeiliSearchBarState<T extends Object> extends State<MeiliSearchBar<T>> {
  final textSubject = BehaviorSubject.seeded('');
  final isSearchControllerOpen = BehaviorSubject.seeded(false);
  final queryStream = BehaviorSubject<MultiSearchQuery?>.seeded(null);
  //caches results
  StreamSubscription? _searchResultSub;
  StreamSubscription? _subscription;

  SearchController? _internalSearchController;
  SearchController get _searchController =>
      widget.searchController ?? _internalSearchController!;

  // Make sure textSubject only fires for non-duplicate events
  void _onSearchControllerChanged() {
    isSearchControllerOpen.add(_searchController.isOpen);
    if (_searchController.text == textSubject.valueOrNull) {
      return;
    }
    textSubject.add(_searchController.text);
  }

  void _onUniqueTextFilterChanged(String textFilter) {
    //Update the query each time a unique text filter appears
    queryStream.add(widget.getQuery(textFilter));
  }

  Future<void> getSuggestions(MultiSearchQuery query) async {
    //this method reacts to text changes and executes the query
  }

  Stream<String> getUniqueTextStreamWithDebounce(Duration? debounce) {
    Stream<String> stream = textSubject.stream;
    if (debounce != null) {
      stream = stream.debounceTime(debounce);
    }
    return stream;
  }

  @override
  void initState() {
    super.initState();
    if (widget.searchController == null) {
      _internalSearchController = SearchController();
    }
    _searchController.addListener(_onSearchControllerChanged);
    _subscription = getUniqueTextStreamWithDebounce(widget.debounce)
        .listen(_onUniqueTextFilterChanged);

    //only query results when there is a query and the search panel is open
    _searchResultSub = Rx.combineLatest2(
      isSearchControllerOpen.stream,
      queryStream.stream,
      (a, b) => (isOpen: a, query: b),
    ).where((event) => event.query != null && event.isOpen).listen((event) {
      //
    });
  }

  @override
  void didUpdateWidget(covariant MeiliSearchBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDebounce = widget.debounce;
    if (newDebounce != oldWidget.debounce) {
      _subscription?.cancel();
      _subscription = getUniqueTextStreamWithDebounce(newDebounce)
          .listen(_onUniqueTextFilterChanged);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.removeListener(_onSearchControllerChanged);
    _subscription?.cancel().then((_) => textSubject.close());
    _searchResultSub?.cancel();
    _subscription = null;
    _searchResultSub = null;
    _internalSearchController = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MultiSearchQuery>(
        stream: queryStream.whereNotNull(),
        builder: (context, snapshot) {
          final query = snapshot.data;
          if (query == null) {
            return const SizedBox.shrink();
          }
          return MeiliSearchOffsetBasedSearchQueryBuilder<T>(
            query: query,
            client: widget.client,
            mapper: widget.mapper,
            builder: (context, state, fetchMore, refresh) {
              final items = state.aggregatedResult;
              debugPrint(
                  'Items from builder: ${items.length}, ${items.map((e) => e.parsed).join(',')}');
              return SearchAnchor(
                key: UniqueKey(),
                searchController: _searchController,
                builder: (context, controller) {
                  return SearchBar(
                    controller: controller,
                    onTap: () {
                      controller.openView();
                    },
                    onChanged: (_) {
                      controller.openView();
                    },
                    padding: const MaterialStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16.0)),
                    leading: const Icon(Icons.search),
                    trailing: [
                      IconButton(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  );
                },
                viewBuilder: (suggestions) {
                  final widgetList = suggestions.toList();
                  final preloadCount = widget.preloadCount ?? 5;

                  return ListView.builder(
                    itemCount: widgetList.length,
                    itemBuilder: (context, index) {
                      //reached end of the list
                      if (index + preloadCount >= widgetList.length) {
                        //it's safe to call this here, even when there are multiple builds
                        fetchMore();
                      }
                      return widgetList[index];
                    },
                  );
                },
                suggestionsBuilder: (context, controller) {
                  debugPrint("suggestionsBuilder called! ${controller.text}");
                  return items.map(
                    (e) =>
                        widget.itemBuilder?.call(context, e) ??
                        DefaultMeiliSearchItemWidget(
                          key: ValueKey(e),
                          item: e,
                          displayAttribute: widget.displayAttribute,
                          itemToString: widget.itemToString,
                          postTag: query.queries
                              .firstWhereOrNull(
                                (element) => element.highlightPostTag != null,
                              )
                              ?.highlightPostTag,
                          preTag: query.queries
                              .firstWhereOrNull(
                                (element) => element.highlightPreTag != null,
                              )
                              ?.highlightPreTag,
                          onTap: () {
                            final str = widget.itemToString?.call(e.parsed) ??
                                e.src[widget.displayAttribute] ??
                                e.parsed.toString();
                            controller.closeView(str);
                          },
                        ),
                  );
                },
              );
            },
          );
        });
  }
}
