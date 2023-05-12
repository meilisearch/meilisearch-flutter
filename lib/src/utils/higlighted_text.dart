import 'package:flutter/widgets.dart';

/// Takes an input string that can have highlighting and returns its parts.
/// each part has an isHighlighted text
Iterable<({String text, bool isHighlighted})> parseHighligtableString({
  required String text,
  required String preTag,
  required String postTag,
}) sync* {
  assert(preTag != postTag,
      "Pre ($preTag) and post ($postTag) tags can't be the same string");
  if (text.isEmpty) {
    yield (text: text, isHighlighted: false);
    return;
  }
  final preIndex = text.indexOf(preTag);
  final postIndex = text.indexOf(postTag);
  if (preIndex < 0 || postIndex < 0) {
    //if the text doesn't contain pre/post tags, there is no need for highlighting
    yield (text: text, isHighlighted: false);
  } else {
    //before the pre tag should be normal text
    final beforePre = preIndex == 0 ? null : text.substring(0, preIndex);
    //after the post tag might be normal or highlighted
    final afterPost = text.substring(postIndex + postTag.length);
    //between the Pre and Post tags is the highlighted text
    final between = text.substring(preIndex + preTag.length, postIndex);
    if (beforePre != null && beforePre.isNotEmpty) {
      yield (text: beforePre, isHighlighted: false);
    }
    yield (text: between, isHighlighted: true);
    if (afterPost.isNotEmpty) {
      yield* parseHighligtableString(
        text: afterPost,
        postTag: postTag,
        preTag: preTag,
      );
    }
  }
}

// a [highlightedStyle] must be provided
TextSpan textSpanFromHighligtableString(
  String? text, {
  required String preTag,
  required String postTag,
  required TextStyle highlightedStyle,
  TextSpan? whenNullOrEmpty,
  TextStyle? normalStyle,
}) {
  if (text == null || text.isEmpty) {
    return whenNullOrEmpty ?? const TextSpan();
  }
  final parts = parseHighligtableString(
    text: text,
    preTag: preTag,
    postTag: postTag,
  ).toList(growable: false);

  return TextSpan(
    children: parts
        .map(
          (e) => TextSpan(
            text: e.text,
            style: e.isHighlighted ? highlightedStyle : normalStyle,
          ),
        )
        .toList(),
  );
}
