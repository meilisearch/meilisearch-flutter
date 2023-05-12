import 'package:example/setup.dart';
import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';

import 'src/models/book.dart';

final client = MeiliSearchClient('http://localhost:7700', 'masterKey');
final indexFuture = setup(client);
void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<MeiliSearchIndex>(
        future: indexFuture,
        builder: (context, snapshot) => snapshot.hasData
            ? HomePage(
                index: snapshot.data!,
              )
            : const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.index,
  });
  final MeiliSearchIndex index;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MeiliSearchIndex get index => widget.index;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        MeiliSearchBar<Book>(
          client: client,
          getQuery: (textFilter) => SearchQuery(
            query: textFilter,
            indexUid: index.uid,
            attributesToHighlight: ['title'],
            highlightPreTag: '<em>',
            highlightPostTag: '</em>',
          ),
          mapper: (src) => Book.fromJson(src),
          preloadCount: 5,
        ),
      ],
    );
  }
}
