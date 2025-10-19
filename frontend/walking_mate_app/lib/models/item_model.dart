class Item {
  final int id;
  final String name;
  final String type;
  final String description;
  final int price;
  final String imageUrl;

  Item({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['item_id'],
      name: json['item_name'],
      type: json['item_type'],
      description: json['description'],
      price: json['price'],
      imageUrl: json['image_url'],
    );
  }
}