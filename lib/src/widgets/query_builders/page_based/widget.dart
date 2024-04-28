// import 'package:collection/collection.dart';
// import 'package:flutter/material.dart';
// import 'package:meilisearch/meilisearch.dart';
// import 'package:meilisearch_ui/meilisearch_ui.dart';

// import 'models.dart';



// class MeilisearchOffsetBasedSearchQueryBuilder<T> extends StatefulWidget {
//   MeilisearchOffsetBasedSearchQueryBuilder({
//     super.key,
//     required this.query,
//     required this.mapper,
//     required this.builder,
//     required this.client,
//     this.onStateChanged,
//     this.fetchInitially = true,
//   })  : assert(query.queries.isNotEmpty, 'Input must have at least one query'),
//         assert(
//           query.queries.none((p0) => p0.page != null || p0.hitsPerPage != null),
//           "An offset-based query shouldn't use page parameters",
//         );

//   final MeiliSearchClient client;

//   /// The multi search query to execute
//   /// Note that this query shouldn't assign offset
//   final MultiSearchQuery query;

//   // Mapper used to convert document to the proper types
//   final MeilisearchDocumentMapper<Map<String, dynamic>, T> mapper;

//   /// Builds a widget that reacts to the latest documents.
//   ///
//   /// Note that it's safe to call fetchMore multiple times.
//   final Widget Function(
//     BuildContext context,
//     MeiliPageBasedDocumentsState<T> state,
//     VoidCallback fetchMore,
//     VoidCallback refresh,
//   ) builder;

//   //Gets called everytime the state changes.
//   final void Function(
//     MeiliPageBasedDocumentsState<T> state,
//     VoidCallback fetchMore,
//     VoidCallback refresh,
//   )? onStateChanged;

//   /// if true (the default) will request the first set of items when the widget starts loading
//   final bool fetchInitially;

//   @override
//   State<MeilisearchOffsetBasedSearchQueryBuilder<T>> createState() =>
//       _MeilisearchOffsetBasedSearchQueryBuilderState<T>();
// }

// class _MeilisearchOffsetBasedSearchQueryBuilderState<T>
//     extends State<MeilisearchOffsetBasedSearchQueryBuilder<T>> {
//   late MeiliPageBasedDocumentsState<T> latestState;
//   void _notifyStateChanged() {
//     widget.onStateChanged?.call(latestState, _fetchMore, refresh);
//   }

//   //This makes sure latestState is set to the initial value (0 offset) and loading

//   @override
//   void initState() {
//     super.initState();
//     latestState = MeiliPageBasedDocumentsState<T>.initial(
//       client: widget.client,
//       multiQuery: widget.query,
//       isLoading: widget.fetchInitially,
//     );
//     _notifyStateChanged();
//     if (widget.fetchInitially) {
//       _requestDataThenSetState();
//     }
//   }

//   @override
//   void didUpdateWidget(
//       covariant MeilisearchOffsetBasedSearchQueryBuilder<T> oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (widget.client != oldWidget.client || widget.query != oldWidget.query) {
//       latestState = MeiliPageBasedDocumentsState<T>.initial(
//         client: widget.client,
//         multiQuery: widget.query,
//       );
//       _notifyStateChanged();
//       _requestDataThenSetState();
//     }
//   }

//   //Sends the request and sets latestState with the new data
//   void _requestDataThenSetState() async {
//     final toExecute = latestState.rawResults.asMap().entries.toList();
//     //maps the index in rawResults to the index in the improved query
//     final ogMap = Map.fromEntries(
//       toExecute
//           .where((element) => element.value.canHaveMore)
//           .mapIndexed((newIndex, og) => MapEntry(og.key, newIndex)),
//     );
//     //maps the index in the improved query, to its original index in rawResults
//     final inverseMap =
//         Map.fromEntries(ogMap.entries.map((e) => MapEntry(e.value, e.key)));

//     //short circuit to not send any request
//     assert(inverseMap.isNotEmpty);

//     final q = MultiSearchQuery(
//       queries: toExecute
//           .where((element) => ogMap.containsKey(element.key))
//           .map((entry) => entry.value.query)
//           .toList(),
//     );
//     final data = await widget.client.multiSearch(q);
//     if (!mounted) {
//       return;
//     }

//     final mappedData = toExecute.map((historyEntry) {
//       final ogIndex = historyEntry.key;
//       final history = historyEntry.value;
//       final improvedIndex = ogMap[ogIndex];
//       if (improvedIndex == null) {
//         final latestRealResult = history.resultHistory.lastOrNull;
//         final fakeResult = SearchResult<MeiliDocumentContainer<T>>(
//           indexUid: history.query.indexUid,
//           query: history.query.query,
//           estimatedTotalHits: latestRealResult?.estimatedTotalHits,
//           facetDistribution: latestRealResult?.facetDistribution,
//           facetStats: latestRealResult?.facetStats,
//           hits: [],
//           limit: history.hitsPerPage,
//           offset: history.latestPage,
//           matchesPosition: {},
//           processingTimeMs: 0,
//         );
//         return fakeResult;
//       } else {
//         final actualResult = data.results[improvedIndex].asSearchResult();
//         return actualResult.map(
//           (src) => MeiliDocumentContainer<T>(
//             src: src,
//             parsed: widget.mapper(src),
//             fromQuery: q.queries[improvedIndex],
//             fromResult: actualResult,
//           ),
//         );
//       }
//     }).toList();

//     setState(() {
//       latestState = latestState.withNewResults(mappedData);
//     });
//     _notifyStateChanged();
//   }

//   //progress the state by pageSize and then request data
//   void _fetchMore() {
//     // don't fetch more data since it's already loading
//     // or no more data can be fetched
//     if (latestState.isLoading || !latestState.canHaveMore) {
//       return;
//     }

//     //set it to loading with the new offsets
//     WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {
//         latestState = latestState.withPage();
//       });
//       _notifyStateChanged();
//       //request the data based on the new query
//       _requestDataThenSetState();
//     });
//   }

//   void refresh() {
//     //if it's already loading do nothing
//     if (latestState.isLoading == true) {
//       return;
//     }
//     if (!mounted) {
//       return;
//     }
//     setState(() {
//       latestState = MeiliPageBasedDocumentsState.initial(
//         client: widget.client,
//         multiQuery: widget.query,
//       );
//     });
//     //reset latestState to its initial state
//     _notifyStateChanged();
//     _requestDataThenSetState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return widget.builder(
//       context,
//       latestState,
//       _fetchMore,
//       refresh,
//     );
//   }
// }
