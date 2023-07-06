import 'package:meilisearch/meilisearch.dart';

class MeilisearchResultContainer<T> {
  final T parsed;
  final Map<String, dynamic> src;
  final Map<String, dynamic>? formatted;
  final Searcheable<Map<String, Object?>> fromResult;
  final SearchQuery fromQuery;

  MeilisearchResultContainer({
    required this.src,
    required this.parsed,
    required this.fromQuery,
    required this.fromResult,
  }) : formatted = src['_formatted'];
}
