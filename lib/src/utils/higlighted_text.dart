/// Class to determine whether a string is highlighted or not
class MeiliHighlightableStringPart {
  final String text;
  final bool isHighlighted;

  const MeiliHighlightableStringPart({
    required this.text,
    required this.isHighlighted,
  });
}

/// Takes an input string that can have highlighting and returns its parts.
/// each part has an isHighlighted text
Iterable<MeiliHighlightableStringPart> parseHighligtableString({
  required String text,
  required String preTag,
  required String postTag,
}) sync* {
  assert(preTag != postTag,
      "Pre ($preTag) and post ($postTag) tags can't be the same string");
  if (text.isEmpty) {
    yield MeiliHighlightableStringPart(isHighlighted: false, text: text);
    return;
  }
  final preIndex = text.indexOf(preTag);
  final postIndex = text.indexOf(postTag);
  if (preIndex < 0 || postIndex < 0) {
    //if the text doesn't contain pre/post tags, there is no need for highlighting
    yield MeiliHighlightableStringPart(text: text, isHighlighted: false);
  } else {
    //before the pre tag should be normal text
    final beforePre = preIndex == 0 ? null : text.substring(0, preIndex);
    //after the post tag might be normal or highlighted
    final afterPost = text.substring(postIndex + postTag.length);
    //between the Pre and Post tags is the highlighted text
    final between = text.substring(preIndex + preTag.length, postIndex);
    if (beforePre != null && beforePre.isNotEmpty) {
      yield MeiliHighlightableStringPart(text: beforePre, isHighlighted: false);
    }
    yield MeiliHighlightableStringPart(text: between, isHighlighted: true);
    if (afterPost.isNotEmpty) {
      yield* parseHighligtableString(
        text: afterPost,
        postTag: postTag,
        preTag: preTag,
      );
    }
  }
}
