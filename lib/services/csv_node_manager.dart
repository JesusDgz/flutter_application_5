import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class CsvNodeManager {
  CsvNodeManager({Future<Directory> Function()? documentsDirectoryProvider})
    : _documentsDirectoryProvider =
          documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<String?> exportNodesToCsv(List<List<dynamic>> rows) async {
    final csvData = const ListToCsvConverter().convert(rows);
    final checksum = sha256.convert(utf8.encode(csvData)).toString();
    final fileContent = '# CHECKSUM:$checksum\n$csvData';

    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar configuración de nodos',
        fileName: 'iot_nodes_config.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(fileContent)),
      );
      return null;
    }

    final directory = await _documentsDirectoryProvider();
    final file = File('${directory.path}/iot_nodes_config.csv');
    await file.writeAsString(fileContent);
    return file.path;
  }

  Future<List<List<dynamic>>?> importNodesFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    return importNodesFromCsvContents(await file.readAsString());
  }

  List<List<dynamic>>? importNodesFromCsvBytes(List<int> bytes) {
    return importNodesFromCsvContents(utf8.decode(bytes));
  }

  List<List<dynamic>>? importNodesFromCsvContents(String contents) {
    final headerEnd = contents.indexOf('\n');
    if (headerEnd < 0) return null;

    final checksumLine = contents.substring(0, headerEnd).trimRight();
    if (!checksumLine.startsWith('# CHECKSUM:')) return null;

    final originalChecksum = checksumLine
        .replaceFirst('# CHECKSUM:', '')
        .trim();
    final csvBody = contents.substring(headerEnd + 1);
    final recalculatedChecksum = sha256
        .convert(utf8.encode(csvBody))
        .toString();

    if (originalChecksum != recalculatedChecksum) return null;
    return const CsvToListConverter().convert(csvBody);
  }

  Future<bool> verifyAndImportCsv(String filePath) async {
    return await importNodesFromCsv(filePath) != null;
  }
}
