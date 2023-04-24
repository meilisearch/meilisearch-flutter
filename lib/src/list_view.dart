import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/src/types.dart';

class MeilisearchQueryBuilder<T> extends StatelessWidget {
  const MeilisearchQueryBuilder({
    super.key,
    required this.query,
    required this.mapper,
  });

  final SearchQuery query;
  final DocumentMapper<T> mapper;
  
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
