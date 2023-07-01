import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';

import '../_shared.dart';

class MeiliPageBasedQueryContainer<T> extends MeiliQueryContainerBase<T,
    PaginatedSearchResult<MeilisearchResultContainer<T>>> {
  /// The latest offset that was fetched
  int? get totalHits => resultHistory.lastOrNull?.totalHits;
  int? get totalPages => resultHistory.lastOrNull?.totalPages;
  int get latestPage => query.page ?? 1;
  int get hitsPerPage => query.hitsPerPage ?? 20;

  //useful to know if a page has been fetched or not in O(1) time
  late final resultMap =
      Map.fromEntries(resultHistory.map((e) => MapEntry(e.page!, e)));

  MeiliPageBasedQueryContainer({
    required super.query,
    required super.resultHistory,
  });

  bool isPageWithinBounds(int page) {
    return page >= 1 && page <= (totalPages ?? 0);
  }

  bool isIndexWithinBounds(int index) {
    return index >= 0 && index < (totalHits ?? 0);
  }

  int indexToPage(int index) {
    return (index / hitsPerPage).floor() + 1;
  }

  int firstIndexOfPage(int page) {
    return (page - 1) * hitsPerPage;
  }

  bool wasIndexFetched(int index) {
    return wasPageFetched(indexToPage(index));
  }

  bool wasPageFetched(int index) {
    return resultMap.containsKey(index);
  }

  MeilisearchResultContainer<T>? getResultAtIndex(int index) {
    if (!isIndexWithinBounds(index)) {
      return null;
    }
    final page = indexToPage(index);
    final hits = resultMap[page]?.hits;
    if (hits == null) {
      return null;
    }
    final relativeIndex = index - firstIndexOfPage(page);
    if (relativeIndex < 0 || relativeIndex >= hits.length) {
      return null;
    }
    return hits[relativeIndex];
  }

  MeiliPageBasedQueryContainer<T> withPage(int page) {
    return MeiliPageBasedQueryContainer<T>(
      query: query.copyWith(page: page),
      resultHistory: resultHistory,
    );
  }

  MeiliPageBasedQueryContainer<T> withNewResult(
    PaginatedSearchResult<MeilisearchResultContainer<T>> newRes,
  ) {
    return MeiliPageBasedQueryContainer(
      query: query,
      resultHistory: [...resultHistory, newRes],
    );
  }
}

class MeiliPageBasedDocumentsState<T> extends MeiliBuilderStateBase<
    T,
    PaginatedSearchResult<MeilisearchResultContainer<T>>,
    MeiliPageBasedQueryContainer<T>> {
  MeiliPageBasedDocumentsState._({
    required super.isLoading,
    required super.rawResults,
    required super.client,
  });

  factory MeiliPageBasedDocumentsState.initial({
    required MeiliSearchClient client,
    required MultiSearchQuery multiQuery,
    bool isLoading = true,
  }) {
    final zeroQuery =
        multiQuery.queries.map((e) => e.copyWith(page: 1)).toList();
    return MeiliPageBasedDocumentsState._(
      isLoading: isLoading,
      rawResults: zeroQuery
          .map(
            (e) => MeiliPageBasedQueryContainer<T>(
              query: e,
              resultHistory: [],
            ),
          )
          .toList(),
      client: client,
    );
  }

  MeiliPageBasedDocumentsState<T> withNewOffsets() {
    return copyWith(
      isLoading: true,
      rawResults: rawResults
          .map(
            (perQueryData) => perQueryData.withPage(),
          )
          .toList(),
    );
  }

  MeiliPageBasedDocumentsState<T> withNewResults(
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

  MeiliPageBasedDocumentsState<T> copyWith({
    List<MeiliPageBasedQueryContainer<T>>? rawResults,
    bool? isLoading,
    MeiliSearchClient? client,
  }) {
    return MeiliPageBasedDocumentsState<T>._(
      rawResults: rawResults ?? this.rawResults,
      isLoading: isLoading ?? this.isLoading,
      client: client ?? this.client,
    );
  }
}