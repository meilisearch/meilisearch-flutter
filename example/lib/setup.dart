import 'dart:math';
import 'wait_for.dart';
import 'package:example/src/models/book.dart';
import 'package:meilisearch/meilisearch.dart';

Future<MeiliSearchIndex> setup(MeiliSearchClient client) async {
  final indexTask = await client.createIndex(
    'books${Random().nextInt(1000)}',
    primaryKey: 'id',
  );
  await indexTask.waitFor(client: client);
  final index = client.index(indexTask.indexUid!);
  await index.updateSearchableAttributes(['title']);
  await index.updateDocuments(
    List.generate(
      500,
      (i) => Book(
        id: i,
        title: 'Book $i',
      ).toJson(),
    ),
  );
  return index;
}
