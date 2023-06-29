import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';

import 'utils/books.dart';
import 'utils/client.dart';

void main() {
  group('Offset based', () {
    setUpClient();
    late Map<String, MeiliSearchIndex> indexes;
    late MultiSearchQuery multiQuery;
    setUp(() async => indexes = await createBooksIndexes());
    setUp(() => multiQuery = MultiSearchQuery(
          queries: indexes.entries
              .map(
                (value) => IndexSearchQuery(
                  indexUid: value.value.uid,
                  query: '',
                  limit: 5,
                ),
              )
              .toList(),
        ));
    test('Just query', () async {
      final res = await client.multiSearch(multiQuery);
      expect(res.results.length, indexes.length);
    });
    testWidgets("Initial state", (tester) async {
      await tester.runAsync(() async {
        late VoidCallback _fetchMore;
        late VoidCallback _refresh;
        final listViewKey = GlobalKey();
        final statesHistory = <MeilisearchOffsetBasedDocumentsState<BookDto>>[];
        final stateCompleter =
            Completer<MeilisearchOffsetBasedDocumentsState<BookDto>>();
        
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MeilisearchOffsetBasedQueryBuilder<BookDto>(
              onStateChanged: (state, fetchMore, refresh) {
                _fetchMore = fetchMore;
                _refresh = refresh;
                statesHistory.add(state);
                if (!state.isLoading) stateCompleter.complete(state);
              },
              query: MultiSearchQuery(
                queries: indexes.entries
                    .map(
                      (value) => IndexSearchQuery(
                        indexUid: value.value.uid,
                        query: '',
                        limit: 5,
                      ),
                    )
                    .toList(),
              ),
              mapper: BookDto.fromMap,
              builder: (context, state, fetchMore, refresh) {
                return ListView.builder(
                  key: listViewKey,
                  itemCount: state.itemCount,
                  itemBuilder: (context, index) {
                    final item = state.aggregatedResult[index];
                    return ListTile(
                      title: Text('[$index] ${item.parsed.title}'),
                      subtitle: Text('id: ${item.parsed.bookId}'),
                    );
                  },
                );
              },
              client: client,
            ),
          ),
        );
        //Displays the widget and runs all animations.
        await tester.pumpAndSettle();
        //initial state test
        final listViewWidget = tester.widget<ListView>(find.byKey(listViewKey));
        expect(find.byType(ListTile), findsNothing);
        expect(listViewWidget.childrenDelegate.estimatedChildCount, 0);
        expect(_fetchMore, isNotNull);
        expect(_refresh, isNotNull);

        final afterLoadingState = await stateCompleter.future;
        expect(statesHistory.length, 2);
        final initialState = statesHistory.first;
        expect(initialState.isLoading, true);
        expect(initialState.itemCount, 0);
        expect(initialState.rawResults.length, indexes.length);
        expect(
          initialState.rawResults
              .every((element) => element.accumulatedResults.isEmpty),
          true,
        );
        expect(
          initialState.rawResults
              .every((element) => element.resultHistory.isEmpty),
          true,
        );
        //After loading
        expect(afterLoadingState, statesHistory.last);
        expect(afterLoadingState.isLoading, false);
        expect(afterLoadingState.itemCount, 5 * indexes.length);
        expect(afterLoadingState.rawResults.length, indexes.length);
        expect(
          afterLoadingState.rawResults
              .every((element) => element.accumulatedResults.length == 5),
          true,
        );
        expect(
          afterLoadingState.rawResults
              .every((element) => element.resultHistory.length == 1),
          true,
        );
      });

      //
    });
  });
}
