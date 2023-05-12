import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:rxdart/rxdart.dart';

import 'package:meilisearch_ui/meilisearch_ui.dart';
import 'package:meilisearch_ui/src/utils/aggregate_multi_query_results.dart';

class MeilisearchOffsetBasedDocumentsState<T> {
  late final List<MeilisearchResultContainer<T>> aggregatedResult;
  final List<SearchResult<MeilisearchResultContainer<T>>> rawResults;
  final bool isLoading;

  /// How many items fetched until now
  int get globalOffset => rawResults.map((e) => e.offset ?? 0).sum;

  /// How many items are fetched per request
  int get globalLimit => rawResults.map((e) => e.limit ?? 20).sum;

  /// Query can be null initially
  final MultiSearchQuery? query;
  final MeiliSearchClient client;

  MeilisearchOffsetBasedDocumentsState({
    required this.isLoading,
    required this.rawResults,
    required this.query,
    required this.client,
  }) : aggregatedResult = bestEffortAggregateSearchResults(rawResults);

  MeilisearchOffsetBasedDocumentsState<T> copyWith({
    List<SearchResult<MeilisearchResultContainer<T>>>? rawResults,
    bool? isLoading,
    MultiSearchQuery? query,
    MeiliSearchClient? client,
  }) {
    return MeilisearchOffsetBasedDocumentsState<T>(
      rawResults: rawResults ?? this.rawResults,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      client: client ?? this.client,
    );
  }
}

class MeilisearchOffsetBasedQueryBuilder<T> extends StatefulWidget {
  const MeilisearchOffsetBasedQueryBuilder({
    super.key,
    required this.queryStream,
    required this.mapper,
    required this.builder,
    required this.client,
  });

  final MeiliSearchClient client;

  /// The multi search query stream to listen to
  /// Note that this query shouldn't assign offset
  final Stream<MultiSearchQuery> queryStream;

  // Mapper used to convert document to the proper types
  final MeilisearchDocumentMapper<Map<String, dynamic>, T> mapper;

  /// Builds a widget that reacts to the latest documents.
  ///
  /// Note that it's safe to call fetchMore multiple times.
  final Widget Function(
    BuildContext context,
    MeilisearchOffsetBasedDocumentsState<T> state,
    void Function() fetchMore,
    void Function() refresh,
  ) builder;

  @override
  State<MeilisearchOffsetBasedQueryBuilder<T>> createState() =>
      _MeilisearchOffsetBasedQueryBuilderState<T>();
}

class _MeilisearchOffsetBasedQueryBuilderState<T>
    extends State<MeilisearchOffsetBasedQueryBuilder<T>> {
  Stream<MultiSearchQuery>? currentQueryStream;
  StreamSubscription? currentSub;

  final refreshSignal = BehaviorSubject<bool>.seeded(true);
  final latestState =
      BehaviorSubject<MeilisearchOffsetBasedDocumentsState<T>>();

  MultiSearchQuery progressQueryByRespectiveLimit(
    MultiSearchQuery original,
    MeilisearchOffsetBasedDocumentsState<T>? latestState,
  ) {
    return MultiSearchQuery(
      queries: original.queries.mapIndexed(
        //TODO(ahmednfwela): change this after https://github.com/meilisearch/meilisearch-dart/issues/305 is fixed
        (index, e) {
          final relatedResult = latestState?.rawResults[index];
          return SearchQuery(
            //
            offset: (relatedResult?.offset ?? 0) + (e.limit ?? 20),
            // in an offset-based UI, pagination should never be used
            hitsPerPage: null,
            page: null,
            //remove this if copyWith exists
            query: e.query,
            indexUid: e.indexUid,
            attributesToCrop: e.attributesToCrop,
            attributesToHighlight: e.attributesToHighlight,
            attributesToRetrieve: e.attributesToRetrieve,
            cropLength: e.cropLength,
            cropMarker: e.cropMarker,
            facets: e.facets,
            filter: e.filter,
            filterExpression: e.filterExpression,
            highlightPostTag: e.highlightPostTag,
            highlightPreTag: e.highlightPreTag,
            limit: e.limit,
            matchingStrategy: e.matchingStrategy,
            showMatchesPosition: e.showMatchesPosition,
            sort: e.sort,
          );
        },
      ).toList(),
    );
  }

  void initLatestStream() {
    final currentQueryStream = this.currentQueryStream;
    if (currentQueryStream == null) {
      return;
    }
    currentSub?.cancel();
    //from the original query, we should create a new query with the offset set to the latest offset + limit
    currentSub = Rx.combineLatest2(
      refreshSignal.stream.where((event) => event).distinct(),
      currentQueryStream,
      (a, b) => b,
    ).switchMap((inputQuery) {
      assert(
        inputQuery.queries.none((p0) => p0.offset != null),
        "The query shouldn't have an offset since the widget automatically assigns it.",
      );
      assert(
        inputQuery.queries
            .none((p0) => p0.page != null || p0.hitsPerPage != null),
        "An offset-based query shouldn't use page parameters",
      );
      final latestStateValue = latestState.valueOrNull;
      final newQuery =
          progressQueryByRespectiveLimit(inputQuery, latestStateValue);

      return widget.client.multiSearch(newQuery).asStream().map(
            (result) => (
              newQuery,
              result,
            ),
          );
    }).map((event) {
      final (query, result) = event;
      return MeilisearchOffsetBasedDocumentsState(
        client: widget.client,
        //stop loading until the next fetchMore call
        isLoading: false,
        query: query,
        rawResults: result.results.mapIndexed((index, e) {
          return e.asSearchResult().map(
            (src) {
              final item = widget.mapper(src);
              return MeilisearchResultContainer(
                src: src,
                parsed: item,
                fromQuery: query.queries[index],
                fromResult: e,
              );
            },
          );
        }).toList(),
      );
    }).listen((event) {
      refreshSignal.add(false);
      latestState.add(event);
    });
  }

  @override
  void initState() {
    super.initState();
    currentQueryStream = widget.queryStream;
    initLatestStream();
  }

  @override
  void didUpdateWidget(
      covariant MeilisearchOffsetBasedQueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newStream = widget.queryStream;
    if (currentQueryStream != newStream) {
      currentQueryStream = newStream;
      initLatestStream();
    }
  }

  @override
  void dispose() {
    super.dispose();
    currentSub?.cancel();
  }

  void fetchMore(MeilisearchOffsetBasedDocumentsState<T> latest) {
    // don't fetch more data since it's already loading
    if (latest.isLoading) {
      return;
    }
    refreshSignal.add(true);
  }

  void refresh() {
    refreshSignal.add(true);
    //reset the latest state to a loading state
    latestState.add(
      MeilisearchOffsetBasedDocumentsState<T>(
        isLoading: true,
        query: null,
        rawResults: [],
        client: widget.client,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeilisearchOffsetBasedDocumentsState<T>>(
      stream: latestState.stream,
      initialData: MeilisearchOffsetBasedDocumentsState<T>(
        isLoading: true,
        query: null,
        rawResults: [],
        client: widget.client,
      ),
      builder: (context, snapshot) {
        //snapshot.data will always have a value here since we provided initial data
        final data = snapshot.data!;
        return widget.builder(
          context,
          data,
          () => fetchMore(data),
          refresh,
        );
      },
    );
  }
}
