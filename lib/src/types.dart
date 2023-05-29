import 'package:flutter/widgets.dart';
import 'package:meilisearch/meilisearch.dart';

typedef MeilisearchSearchableWidgetBuilder<T> = Widget Function(
  BuildContext context,
  SearchResult<T> result,
  Widget? child,
);
