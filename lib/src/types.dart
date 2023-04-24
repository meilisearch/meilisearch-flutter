import 'package:flutter/widgets.dart';
import 'package:meilisearch/meilisearch.dart';

typedef DocumentMapper<T> = T Function(Map<String, dynamic> src);

/// A function that builds a widget from a [FirestoreQueryBuilderSnapshot]
///
/// See also [FirebaseDatabaseQueryBuilder].
typedef MeilisearchSearchableWidgetBuilder<T> = Widget Function(
  BuildContext context,
  SearchResult result,
  Widget? child,
);