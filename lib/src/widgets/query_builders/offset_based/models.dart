import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/src/utils/aggregate_multi_query_results.dart';

import '../_shared.dart';

class MeiliOffsetBasedQueryContainer<T extends Object>
    extends MeiliQueryContainerBase<T,
        SearchResult<MeiliDocumentContainer<T>>> {
  /// The latest offset that was fetched
  int get latestOffset => query.offset ?? 0;
  int? get estimatedTotalHits => resultHistory.lastOrNull?.estimatedTotalHits;
  int get limit => query.limit ?? 20;

  ///All the results sorted by offset
  late final List<MeiliDocumentContainer<T>> accumulatedResults =
      resultHistory.map((e) => e.hits).flattened.toList();

  /// true if fetching more items will actually be useful and not return an
  /// empty collection

  bool get canHaveMore =>
      resultHistory.isEmpty ||
      (resultHistory.last.hits.length >= (resultHistory.last.limit ?? 20));

  MeiliOffsetBasedQueryContainer({
    required super.query,
    required super.resultHistory,
  });

  MeiliOffsetBasedQueryContainer<T> withNewOffsets() {
    return MeiliOffsetBasedQueryContainer<T>(
      query: query.copyWith(offset: latestOffset + limit),
      resultHistory: resultHistory,
    );
  }

  MeiliOffsetBasedQueryContainer<T> withNewResult(
    SearchResult<MeiliDocumentContainer<T>> newRes,
  ) {
    return MeiliOffsetBasedQueryContainer(
      query: query,
      resultHistory: [...resultHistory, newRes],
    );
  }
}

class MeiliOffsetBasedDocumentsState<T extends Object>
    extends MeiliBuilderStateBase<T, SearchResult<MeiliDocumentContainer<T>>,
        MeiliOffsetBasedQueryContainer<T>> {
  MeiliOffsetBasedDocumentsState._({
    required super.isLoading,
    required super.rawResults,
    required super.client,
  });

  static List<MeiliDocumentContainer<T>>
      meiliRoundRobinResults<T extends Object>(
    List<MeiliQueryContainerBase<T, SearchResult<MeiliDocumentContainer<T>>>>
        rawResults,
  ) {
    final result = <MeiliDocumentContainer<T>>[];
    final maxHistoryCount = rawResults.isEmpty
        ? 0
        : rawResults.map((e) => e.resultHistory.length).max;
    for (var i = 0; i < maxHistoryCount; i++) {
      for (var perQueryResult in rawResults) {
        final entry = i < perQueryResult.resultHistory.length
            ? perQueryResult.resultHistory[i]
            : null;
        if (entry == null) {
          continue;
        }
        result.addAll(entry.hits);
      }
    }
    return result;
  }

  late final List<MeiliDocumentContainer<T>> aggregatedResult =
      bestEffortAggregateSearchResults(meiliRoundRobinResults(rawResults));

  /// can any of the queries get executed
  late final bool canHaveMore =
      rawResults.any((element) => element.canHaveMore);

  /// How many items fetched until now
  late final int itemCount = aggregatedResult.length;

  factory MeiliOffsetBasedDocumentsState.initial({
    required MeiliSearchClient client,
    required MultiSearchQuery multiQuery,
    bool isLoading = true,
  }) {
    final zeroQuery =
        multiQuery.queries.map((e) => e.copyWith(offset: 0)).toList();
    return MeiliOffsetBasedDocumentsState._(
      isLoading: isLoading,
      rawResults: zeroQuery
          .map(
            (e) => MeiliOffsetBasedQueryContainer<T>(
              query: e,
              resultHistory: [],
            ),
          )
          .toList(),
      client: client,
    );
  }

  MeiliOffsetBasedDocumentsState<T> withNewOffsets() {
    return copyWith(
      isLoading: true,
      rawResults: rawResults
          .map(
            (perQueryData) => perQueryData.withNewOffsets(),
          )
          .toList(),
    );
  }

  MeiliOffsetBasedDocumentsState<T> withNewResults(
    List<SearchResult<MeiliDocumentContainer<T>>> newResults,
  ) {
    assert(newResults.length == rawResults.length);

    return copyWith(
      isLoading: false,
      rawResults: rawResults
          .mapIndexed((index, e) => e.withNewResult(newResults[index]))
          .toList(),
    );
  }

  MeiliOffsetBasedDocumentsState<T> copyWith({
    List<MeiliOffsetBasedQueryContainer<T>>? rawResults,
    bool? isLoading,
    MeiliSearchClient? client,
  }) {
    return MeiliOffsetBasedDocumentsState<T>._(
      rawResults: rawResults ?? this.rawResults,
      isLoading: isLoading ?? this.isLoading,
      client: client ?? this.client,
    );
  }
}
