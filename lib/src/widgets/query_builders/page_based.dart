import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';

class MeiliSearchPageBasedQueryBuilder<T> extends StatefulWidget {
  const MeiliSearchPageBasedQueryBuilder({super.key});

  @override
  State<MeiliSearchPageBasedQueryBuilder<T>> createState() =>
      _MeiliSearchPageBasedQueryBuilderState<T>();
}

class _MeiliSearchPageBasedQueryBuilderState<T>
    extends State<MeiliSearchPageBasedQueryBuilder<T>> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
