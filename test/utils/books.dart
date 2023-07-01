import 'package:collection/collection.dart';
import 'package:meilisearch/meilisearch.dart';

import 'client.dart';
import 'wait_for.dart';

const kbookId = 'book_id';
const ktitle = 'title';
const ktag = 'tag';
const kid = 'id';

const _localesBookMap = {
  //arabic
  'ar': 'كتاب',
  //english
  'en': 'book',
  //spanish
  'es': 'libro',
  //greek
  // 'el': 'Βιβλίο'
};
final tags = ['t1', 't2', 't3', 't4'];

Future<Map<String, MeiliSearchIndex>> createBooksIndexes({
  String? uid,
  int baseCount = 10,
}) async {
  uid ??= randomUid();
  return await Future.wait(
    _localesBookMap.keys.mapIndexed(
      (index, locale) => createBooksIndex(
        locale: locale,
        uid: uid,
        count: baseCount + index,
      ).then((value) => MapEntry(locale, value)),
    ),
  ).then((value) => Map.fromEntries(value));
}

Future<MeiliSearchIndex> createBooksIndex({
  String? uid,
  required String locale,
  required int count,
}) async {
  final index = client.index((uid ?? randomUid()) + locale);
  final docs = List.generate(
    count,
    (index) => BookDto(
      bookId: index,
      title: '${_localesBookMap[locale]} $index',
      tag: tags[index % tags.length],
    ),
  );
  final response = await index
      .addDocuments(docs.map((e) => e.toMap()).toList())
      .waitFor(client: client);
  await index.updateSearchableAttributes([ktitle]).waitFor(client: client);
  await index.updateFilterableAttributes([ktag]).waitFor(client: client);
  if (response.status != 'succeeded') {
    throw Exception(
      'Impossible to process test suite, the documents were not added into the index.',
    );
  }
  return index;
}

class BookDto {
  final int bookId;
  final String title;
  final String? tag;

  const BookDto({
    required this.bookId,
    required this.title,
    required this.tag,
  });

  Map<String, dynamic> toMap() {
    return {
      kbookId: bookId,
      ktitle: title,
      ktag: tag,
    };
  }

  factory BookDto.fromMap(Map<String, dynamic> map) {
    return BookDto(
      bookId: map[kbookId] as int,
      title: map[ktitle] as String,
      tag: map[ktag] as String?,
    );
  }
}
