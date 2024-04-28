import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';

import '../_shared.dart';

class MeiliPageBasedQueryContainer<T extends Object>
    extends MeiliQueryContainerBase<T,
        PaginatedSearchResult<MeiliDocumentContainer<T>>> {
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

  MeiliDocumentContainer<T>? getResultAtIndex(int index) {
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
    PaginatedSearchResult<MeiliDocumentContainer<T>> newRes,
  ) {
    return MeiliPageBasedQueryContainer(
      query: query,
      resultHistory: [...resultHistory, newRes],
    );
  }
}

class MeiliPageBasedDocumentsState<T extends Object>
    extends MeiliBuilderStateBase<
        T,
        PaginatedSearchResult<MeiliDocumentContainer<T>>,
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

  MeiliPageBasedDocumentsState<T> withPage(int page) {
    return copyWith(
      isLoading: true,
      rawResults: rawResults
          .map(
            (perQueryData) => perQueryData.withPage(page),
          )
          .toList(),
    );
  }

  MeiliPageBasedDocumentsState<T> withNewResults(
    List<PaginatedSearchResult<MeiliDocumentContainer<T>>> newResults,
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

class MeiliDataTableSource extends DataTableSource {
  @override
  DataRow? getRow(int index) {
    // TODO: implement getRow
    throw UnimplementedError();
  }

  @override
  // TODO: implement isRowCountApproximate
  bool get isRowCountApproximate => throw UnimplementedError();

  @override
  // TODO: implement rowCount
  int get rowCount => throw UnimplementedError();

  @override
  // TODO: implement selectedRowCount
  int get selectedRowCount => throw UnimplementedError();
}
