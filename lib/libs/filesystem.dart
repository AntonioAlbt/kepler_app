import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> get cacheDirPath async => (await getApplicationCacheDirectory()).path;
Future<String> get userDataDirPath async => (await getApplicationDocumentsDirectory()).path;
Future<String> get appDataDirPath async => (await getApplicationSupportDirectory()).path;

Future<bool> fileExists(String fn) => File(fn).exists();

Future<bool> writeFileBin(String fn, List<int> data) async {
  final file = File(fn);
  try {
    final sink = file.openWrite();
    sink.add(data);
    sink.close();
    return true;
  } catch (_) {
    return false;
  }
}
Future<bool> writeFile(String fn, String data) => writeFileBin(fn, utf8.encode(data));

Future<List<int>?> readFileBin(String fn) async {
  if (!(await fileExists(fn))) return null;
  final file = File(fn);
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
Future<String?> readFile(String fn) async {
  final raw = await readFileBin(fn);
  if (raw == null) return null;
  return utf8.decode(raw);
}
