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
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<List<MeiliSearchIndex>>(
        future: indexFuture,
        builder: (context, snapshot) => snapshot.hasData
            ? HomePage(
                indexes: snapshot.data!,
              )
            : const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.indexes,
  });
  final List<MeiliSearchIndex> indexes;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final sc = ScrollController();
  List<MeiliSearchIndex> get indexes => widget.indexes;
  @override
  Widget build(BuildContext context) {
    return MeiliSearchOffsetBasedSearchQueryBuilder<Book>(
      client: client,
      mapper: Book.fromJson,
      query: MultiSearchQuery(
        queries: indexes
            .map(
              (index) => IndexSearchQuery(
                indexUid: index.uid,
                query: '',
                limit: 30,
              ),
            )
            .toList(),
      ),
      builder: (context, state, fetchMore, refresh) => Scaffold(
        appBar: AppBar(
          title: Text("Books (${state.itemCount})"),
          actions: [
            IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
            IconButton(onPressed: fetchMore, icon: const Icon(Icons.more)),
          ],
        ),
        body: ListView.builder(
          controller: sc,
          itemCount: state.itemCount + (state.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index + 1 >= state.itemCount) {
              fetchMore();
            }
            
            if (state.isLoading && index == state.itemCount) {
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            }
            final item = state.aggregatedResult[index];
            return ListTile(
              title: Text('[$index] ${item.parsed.title}'),
              subtitle: Text('id: ${item.parsed.id}'),
            );
          },
        ),
      ),
    );
  }
}
