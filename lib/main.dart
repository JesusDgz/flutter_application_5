import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';

import 'services/csv_node_manager.dart';

void main() {
  runApp(const NodeConfigApp());
}

class NodeConfigApp extends StatelessWidget {
  const NodeConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuración IoT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B61)),
        useMaterial3: true,
      ),
      home: const NodeConfigPage(),
    );
  }
}

class NodeConfigPage extends StatefulWidget {
  const NodeConfigPage({super.key});

  @override
  State<NodeConfigPage> createState() => _NodeConfigPageState();
}

class _NodeConfigPageState extends State<NodeConfigPage> {
  final CsvNodeManager _manager = CsvNodeManager();
  List<List<dynamic>> _rows = [
    ['id', 'nombre', 'tipo', 'ubicacion', 'estado'],
    [
      'N-001',
      'Temperatura invernadero',
      'Temperatura',
      'Invernadero',
      'Activo',
    ],
    ['N-002', 'Humedad del suelo', 'Humedad', 'Sector norte', 'Activo'],
    ['N-003', 'Luz ambiental', 'Luminosidad', 'Almacen', 'Inactivo'],
  ];
  String? _lastExportPath;
  bool _busy = false;

  List<List<dynamic>> get _nodes => _rows.skip(1).toList();

  Future<void> _export() async {
    await _runTask(() async {
      final path = await _manager.exportNodesToCsv(_rows);
      if (!kIsWeb) _lastExportPath = path;
      _showMessage(
        kIsWeb
            ? 'Descarga de iot_nodes_config.csv iniciada.'
            : 'CSV guardado en $path',
      );
    });
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: kIsWeb,
    );
    final selectedFile = result?.files.single;
    if (selectedFile == null || !mounted) return;

    await _runTask(() async {
      List<List<dynamic>>? importedRows;
      if (kIsWeb) {
        final bytes = selectedFile.bytes;
        if (bytes == null) {
          _showMessage('El navegador no pudo leer el CSV seleccionado.');
          return;
        }
        importedRows = _manager.importNodesFromCsvBytes(bytes);
      } else {
        final path = selectedFile.path;
        if (path == null) {
          _showMessage('No se pudo acceder al archivo seleccionado.');
          return;
        }
        importedRows = await _manager.importNodesFromCsv(path);
      }
      if (importedRows == null) {
        _showMessage(
          'CSV inválido o checksum incorrecto. No se importaron datos.',
        );
        return;
      }
      final validRows = importedRows;
      const expectedHeader = ['id', 'nombre', 'tipo', 'ubicacion', 'estado'];
      if (validRows.isEmpty ||
          !listEquals(validRows.first, expectedHeader) ||
          validRows.skip(1).any((row) => row.length != expectedHeader.length)) {
        _showMessage('El CSV no contiene las columnas de nodos esperadas.');
        return;
      }
      setState(() => _rows = validRows);
      _showMessage('${validRows.length - 1} nodos importados correctamente.');
    });
  }

  Future<void> _runTask(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on Exception catch (error) {
      _showMessage('No se pudo completar la operación: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nodos IoT'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _import,
            tooltip: 'Importar CSV',
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            onPressed: _busy ? null : _export,
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.primary,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                children: [
                  Icon(Icons.sensors, color: colors.onPrimary, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_nodes.length} nodos configurados',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          'Respalda o restaura la configuración local',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onPrimary.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _nodes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final node = _nodes[index];
                  final active = node[4].toString().toLowerCase() == 'activo';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: active
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.sensors,
                        color: active
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    title: Text(node[1].toString()),
                    subtitle: Text('${node[0]}  ·  ${node[2]}  ·  ${node[3]}'),
                    trailing: Text(
                      node[4].toString(),
                      style: TextStyle(
                        color: active
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_lastExportPath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Último archivo: $_lastExportPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Importar CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Exportar CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
