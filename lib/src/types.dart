import 'package:flutter/widgets.dart';
import 'package:meilisearch/meilisearch.dart';

typedef DocumentMapper<T> = T Function(Map<String, dynamic> src);

typedef MeilisearchSearchableWidgetBuilder<T> = Widget Function(
  BuildContext context,
  SearchResult<T> result,
  Widget? child,
);