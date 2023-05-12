class Book {
  final int id;
  final String title;

  const Book({
    required this.id,
    required this.title,
  });

  factory Book.fromJson(Map<String, dynamic> src) {
    return Book(
      id: src['id'],
      title: src['title'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }

  @override
  String toString() {    
    return title;
  }
}
