import 'package:meilisearch/meilisearch.dart';

abstract class MeiliQueryContainerBase<T extends Object,
    TSearchResult extends Searcheable<MeiliDocumentContainer<T>>> {
  ///The latest query that was executed, or is getting executed now.
  final IndexSearchQuery query;

  ///All the results at different points
  final List<TSearchResult> resultHistory;

  /// true if the query has been executed before
  late final bool executedAtLeastOnce = resultHistory.isNotEmpty;

  MeiliQueryContainerBase({
    required this.query,
    required this.resultHistory,
  });
}

abstract class MeiliBuilderStateBase<
    T extends Object,
    TSearchResult extends Searcheable<MeiliDocumentContainer<T>>,
    TContainer extends MeiliQueryContainerBase<T, TSearchResult>> {
  final List<TContainer> rawResults;
  final bool isLoading;
  final MeiliSearchClient client;

  MeiliBuilderStateBase({
    required this.isLoading,
    required this.rawResults,
    required this.client,
  });
}
