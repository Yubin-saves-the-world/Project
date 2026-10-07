class SelectedPhoto {
  const SelectedPhoto({required this.path, required this.byteLength});
  final String path;
  final int byteLength;

  Map<String, dynamic> toJson() => {'path': path, 'byte_length': byteLength};
  factory SelectedPhoto.fromJson(Map<String, dynamic> json) => SelectedPhoto(
    path: json['path'] as String,
    byteLength: json['byte_length'] as int,
  );
}

enum PhotoSlot { front, side, goal }

enum PhotoSource { camera, gallery }
