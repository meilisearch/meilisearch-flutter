import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';

List<MeiliDocumentContainer<T>>
    bestEffortAggregateSearchResults<T extends Object>(
  List<MeiliDocumentContainer<T>> raw,
) {
  return raw.sortedBy<num>((element) => element.rankingScore ?? 0).toList();
}
