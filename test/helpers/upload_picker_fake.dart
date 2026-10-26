import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

final class MemoryUploadFile extends PlatformFile {
  @override
  final String name;
  final Uint8List bytes;
  MemoryUploadFile(this.name, List<int> bytes)
    : bytes = Uint8List.fromList(bytes);
  @override
  Uri get uri => Uri.parse('memory:$name');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class UploadPickerFake extends FilePickerPlatform {
  List<PlatformFile> files;
  UploadPickerFake(this.files);
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files;
}
