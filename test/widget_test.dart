import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_5/services/csv_node_manager.dart';

void main() {
  late Directory temporaryDirectory;
  late CsvNodeManager manager;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('iot_nodes_');
    manager = CsvNodeManager(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('exports and imports rows when the checksum is valid', () async {
    final rows = [
      ['id', 'nombre'],
      ['N-001', 'Sensor de temperatura'],
    ];

    final path = (await manager.exportNodesToCsv(rows))!;

    expect(await manager.verifyAndImportCsv(path), isTrue);
    expect(await manager.importNodesFromCsv(path), rows);
  });

  test('rejects a CSV modified after export', () async {
    final path = (await manager.exportNodesToCsv([
      ['id', 'nombre'],
      ['N-001', 'Sensor de temperatura'],
    ]))!;
    final file = File(path);
    final contents = await file.readAsString();
    await file.writeAsString(contents.replaceFirst('temperatura', 'presion'));

    expect(await manager.verifyAndImportCsv(path), isFalse);
    expect(await manager.importNodesFromCsv(path), isNull);
  });
}
