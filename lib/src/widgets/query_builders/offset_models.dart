import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';
import 'package:meilisearch_ui/src/utils/aggregate_multi_query_results.dart';

class PerQuerySearchResults<T> {
  ///The latest query that was executed, or is getting executed now.
  final IndexSearchQuery query;

  ///All the results at different offsets
  final List<SearchResult<MeilisearchResultContainer<T>>> resultHistory;

  ///All the results sorted by offset
  final List<MeilisearchResultContainer<T>> accumulatedResults;

  /// The latest offset that was fetched
  int get latestOffset => query.offset ?? 0;
  int? get estimatedTotalHits => resultHistory.lastOrNull?.estimatedTotalHits;

  int get limit => query.limit ?? 20;

  bool get executedAtLeastOnce => resultHistory.isNotEmpty;

  bool get canHaveMore =>
      resultHistory.isEmpty ||
      (resultHistory.last.hits.length >= (resultHistory.last.limit ?? 20));

  PerQuerySearchResults({
    required this.query,
    required this.resultHistory,
  }) : accumulatedResults = resultHistory.map((e) => e.hits).flattened.toList();

  PerQuerySearchResults<T> withNewOffsets() {
    return PerQuerySearchResults<T>(
      query: query.copyWith(offset: latestOffset + limit),
      resultHistory: resultHistory,
    );
  }

  PerQuerySearchResults<T> withNewResult(
    SearchResult<MeilisearchResultContainer<T>> newRes,
  ) {
    return PerQuerySearchResults(
      query: query,
      resultHistory: [...resultHistory, newRes],
    );
  }
}

class MeilisearchOffsetBasedDocumentsState<T> {
  final List<MeilisearchResultContainer<T>> aggregatedResult;
  final List<PerQuerySearchResults<T>> rawResults;
  final bool isLoading;

  /// can any of the queries get executed
  bool get canHaveMore => rawResults.any((element) => element.canHaveMore);

  /// How many items fetched until now
  int get itemCount => aggregatedResult.length;

  final MeiliSearchClient client;

  MeilisearchOffsetBasedDocumentsState({
    required this.isLoading,
    required this.rawResults,
    required this.client,
  }) : aggregatedResult = bestEffortAggregateSearchResults(
          rawResults.map((e) => e.accumulatedResults).flattened.toList(),
        );

  factory MeilisearchOffsetBasedDocumentsState.initial({
    required MeiliSearchClient client,
    required MultiSearchQuery multiQuery,
    bool isLoading = true,
  }) {
    final zeroQuery =
        multiQuery.queries.map((e) => e.copyWith(offset: 0)).toList();
    return MeilisearchOffsetBasedDocumentsState(
      isLoading: isLoading,
      rawResults: zeroQuery
          .map(
            (e) => PerQuerySearchResults<T>(
              query: e,
              resultHistory: [],
            ),
          )
          .toList(),
      client: client,
    );
  }

  MeilisearchOffsetBasedDocumentsState<T> withNewOffsets() {
    return copyWith(
      isLoading: true,
      rawResults: rawResults
          .map(
            (perQueryData) => perQueryData.withNewOffsets(),
          )
          .toList(),
    );
  }

  MeilisearchOffsetBasedDocumentsState<T> withNewResults(
    List<SearchResult<MeilisearchResultContainer<T>>> newResults,
  ) {
    assert(newResults.length == rawResults.length);

    return copyWith(
      isLoading: false,
      rawResults: rawResults
          .mapIndexed((index, e) => e.withNewResult(newResults[index]))
          .toList(),
    );
  }

  MeilisearchOffsetBasedDocumentsState<T> copyWith({
    List<PerQuerySearchResults<T>>? rawResults,
    bool? isLoading,
    MeiliSearchClient? client,
  }) {
    return MeilisearchOffsetBasedDocumentsState<T>(
      rawResults: rawResults ?? this.rawResults,
      isLoading: isLoading ?? this.isLoading,
      client: client ?? this.client,
    );
  }
}
