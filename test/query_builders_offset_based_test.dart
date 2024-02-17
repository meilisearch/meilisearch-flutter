import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:meilisearch_ui/meilisearch_ui.dart';
import 'package:rxdart/rxdart.dart';

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
        VoidCallback? _fetchMore;
        VoidCallback? _refresh;
        final listViewKey = GlobalKey();
        final statesHistory =
            ReplaySubject<MeiliOffsetBasedDocumentsState<BookDto>>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MeiliSearchOffsetBasedSearchQueryBuilder<BookDto>(
                onStateChanged: (state, fetchMore, refresh) {
                  _fetchMore = fetchMore;
                  _refresh = refresh;
                  statesHistory.add(state);
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
                builder: listViewqueryBuilder(listViewKey),
                client: client,
              ),
            ),
          ),
        );
        //Displays the widget and runs all animations.
        await tester.pumpAndSettle();
        //initial state test
        var listViewWidget = tester.widget<ListView>(find.byKey(listViewKey));
        expect(find.byType(ListTile), findsNothing);
        expect(listViewWidget.childrenDelegate.estimatedChildCount, 0);
        expect(_fetchMore, isNotNull);
        expect(_refresh, isNotNull);

        final initialState = await statesHistory.elementAt(0);
        expect(initialState.isLoading, true);
        expect(initialState.itemCount, 0);
        expect(initialState.canHaveMore, true);
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
        final afterLoadingState = await statesHistory.elementAt(1);
        expect(afterLoadingState.isLoading, false);
        expect(afterLoadingState.canHaveMore, true);
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
        //refresh UI
        await tester.pumpAndSettle();
        listViewWidget = tester.widget<ListView>(find.byKey(listViewKey));
        expect(
          listViewWidget.childrenDelegate.estimatedChildCount,
          5 * indexes.length,
        );
        //The visible ListTile vary based on scroll position
        final allListTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        expect(allListTiles.length, isPositive);
      });
    });
    testWidgets("Fetch More", (tester) async {
      await tester.runAsync(() async {
        late VoidCallback _fetchMore;
        final listViewKey = GlobalKey();

        final states =
            ReplaySubject<MeiliOffsetBasedDocumentsState<BookDto>>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MeiliSearchOffsetBasedSearchQueryBuilder<BookDto>(
                onStateChanged: (state, fetchMore, refresh) {
                  _fetchMore = fetchMore;
                  if (states.isClosed) {
                    throw Exception('states are already closed');
                  }
                  states.add(state);

                  if (!state.canHaveMore) {
                    states.close();
                  }
                },
                query: MultiSearchQuery(
                  queries: indexes.entries
                      .map(
                        (value) => IndexSearchQuery(
                          indexUid: value.value.uid,
                          query: '',
                          limit: 6,
                        ),
                      )
                      .toList(),
                ),
                mapper: BookDto.fromMap,
                builder: listViewqueryBuilder(listViewKey),
                client: client,
              ),
            ),
          ),
        );
        //Displays the widget and runs all animations.
        await tester.pumpAndSettle();

        //wait for the initial loading to complete
        await states.elementAt(1);
        //then fetch more
        _fetchMore();
        //schedule a new frame so that WidgetsBinding.instance.addPostFrameCallback gets called
        await tester.pump();

        var latestState = await states.elementAt(2);
        expect(latestState.isLoading, true);
        expect(latestState.canHaveMore, true);
        expect(latestState.itemCount, 6 * indexes.length);
        expect(latestState.rawResults.length, indexes.length);
        expect(
          latestState.rawResults
              .every((element) => element.accumulatedResults.length == 6),
          true,
        );
        expect(
          latestState.rawResults
              .every((element) => element.resultHistory.length == 1),
          true,
        );

        latestState = await states.elementAt(3);
        expect(latestState.isLoading, false);
        expect(latestState.canHaveMore, true);
        expect(latestState.itemCount, (2 * 6 * indexes.length) - 3);
        //one of the indexes can't have any more items
        expect(latestState.rawResults.any((element) => !element.canHaveMore),
            true);
        expect(latestState.rawResults.length, indexes.length);
        expect(
          latestState.rawResults
              .any((element) => element.accumulatedResults.length == 2 * 6),
          true,
        );
        expect(
          latestState.rawResults
              .every((element) => element.resultHistory.length == 2),
          true,
        );
        //then fetch more (last fetch that contains data)
        _fetchMore();
        //schedule a new frame so that WidgetsBinding.instance.addPostFrameCallback gets called
        await tester.pump();
        latestState = await states.elementAt(5);
        expect(latestState.canHaveMore, false);


        //then fetch more (no data should be fetched, stream is closed.)
        _fetchMore();
        //schedule a new frame so that WidgetsBinding.instance.addPostFrameCallback gets called
        await tester.pump();
        await states.done;
      });
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}

Widget Function(
  BuildContext context,
  MeiliOffsetBasedDocumentsState<BookDto> state,
  VoidCallback fetchMore,
  VoidCallback refresh,
) listViewqueryBuilder(GlobalKey listViewKey) {
  return (context, state, fetchMore, refresh) => ListView.builder(
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
}
