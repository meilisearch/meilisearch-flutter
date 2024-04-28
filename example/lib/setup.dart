import 'dart:math';
import 'wait_for.dart';
import 'package:example/src/models/book.dart';
import 'package:meilisearch/meilisearch.dart';

Future<List<MeiliSearchIndex>> setup(MeiliSearchClient client) async {
  final indexTask = await client
      .createIndex(
        'books_en_${Random().nextInt(1000)}',
        primaryKey: 'id',
      )
      .waitFor(client: client);

  final index1 = client.index(indexTask.indexUid!);
  await index1.updateSearchableAttributes(['title']).waitFor(client: client);
  await index1.updateDocuments(
    List.generate(
      500,
      (i) => Book(
        id: i,
        title: 'Book $i',
      ).toJson(),
    ),
  );

  final indexTask2 = await client
      .createIndex(
        'books_ar_${Random().nextInt(1000)}',
        primaryKey: 'id',
      )
      .waitFor(client: client);
  final index2 = client.index(indexTask2.indexUid!);
  await index2.updateSearchableAttributes(['title']).waitFor(client: client);
  await index2
      .updateDocuments(
        List.generate(
          500,
          (i) => Book(
            id: i,
            title: 'كتاب $i',
          ).toJson(),
        ),
      )
      .waitFor(client: client);
  return [index1, index2];
}
