import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';

List<T> bestEffortAggregateSearchResults<T>(
  List<Searcheable<T>> raw,
) {
  //TODO(ahmednfwela): sort these results based on relevance
  return raw.map((e) => e.hits).flattened.toList();
}
