import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flux_plugin/flux_plugin.dart';
import 'package:flux_test_app/key_value_editor.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final deviceId = await getId();

      final appDocumentsDir = await path_provider
          .getApplicationDocumentsDirectory();
      final deviceName = await getDeviceName();
      final osName = await getOsName();
      final FluxLogs flux = FluxLogs.instance;
      await flux.init(
        FluxLogsConfig(
          deviceInfo: DeviceInfo(
            platform: 'android',
            bundleId: 'com.example.android',
            deviceId: deviceId,
            deviceName: deviceName,
            osName: osName,
          ),
          releaseMode: false,
          sendLogLevels: {...LogLevel.values},
          enableSocketConnection: true,
        ),
        ApiConfig(token: '', url: 'https://fluxlogs.ru'),
        ReliableBatchQueueOptions(
          storagePath: appDocumentsDir.path,
          flushInterval: Duration(seconds: 30),
        ),
        PrinterOptions(
          maxLineLength: 180,
          chunkSize: 512,
          removeEmptyLines: false,
        ),
      );

      listenToIsolateErrors();

      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          FluxLogs.instance.debug(message, tags: ['external log']);
        }
      };

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
        FluxLogs.instance.error(details.toString(), tags: ['Flutter onError']);
      };

      runApp(const MyApp());
    },
    (error, stackTrace) {
      FluxLogs.instance.error(
        error.toString(),
        stackTrace: stackTrace,
        tags: ['async error'],
      );
    },
  );
}

Future<String> getId() async {
  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    // import 'dart:io'
    var iosDeviceInfo = await deviceInfo.iosInfo;
    return iosDeviceInfo.identifierForVendor ?? 'null';
  } else if (Platform.isAndroid) {
    return (await AndroidId().getId()) ?? 'null';
  }
  return 'null';
}

Future<String> getOsName() async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var release = androidInfo.version.release;
    var sdkInt = androidInfo.version.sdkInt;
    var manufacturer = androidInfo.manufacturer;
    var model = androidInfo.model;
    return 'Android $release (SDK $sdkInt), $manufacturer $model';
  }

  if (Platform.isIOS) {
    var iosInfo = await DeviceInfoPlugin().iosInfo;
    var systemName = iosInfo.systemName;
    var version = iosInfo.systemVersion;
    var name = iosInfo.name;
    var model = iosInfo.model;
    '$systemName $version, $name $model';
  }

  return 'unknown';
}

Future<String> getDeviceName() async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.model;
  }

  if (Platform.isIOS) {
    var iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.modelName;
  }

  return 'unknown';
}

void listenToIsolateErrors() {
  final port = ReceivePort();
  Isolate.current.addErrorListener(port.sendPort);
  port.listen((dynamic error) {
    FluxLogs.instance.error(error.toString(), tags: ['isolate error']);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flux Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final TextEditingController _messageController;
  LogLevel _logLevel = LogLevel.info;
  final Map<String, String> _messageMetaKeys = {};
  final List<String> _messageTags = [];
  bool _sendStackTrace = false;

  final Map<String, String> _defaultMeta = {};
  Timer? _setDefaultMetaDuration;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendEvent() {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text;
    final StackTrace? stackTrace = _sendStackTrace ? StackTrace.current : null;
    switch (_logLevel) {
      case LogLevel.info:
        FluxLogs.instance.info(
          message,
          meta: _messageMetaKeys,
          tags: _messageTags,
          stackTrace: stackTrace,
        );
        break;
      case LogLevel.warn:
        FluxLogs.instance.warn(
          message,
          meta: _messageMetaKeys,
          tags: _messageTags,
          stackTrace: stackTrace,
        );
        break;
      case LogLevel.error:
        FluxLogs.instance.error(
          message,
          meta: _messageMetaKeys,
          tags: _messageTags,
          stackTrace: stackTrace,
        );
        break;
      case LogLevel.debug:
        FluxLogs.instance.debug(
          message,
          meta: _messageMetaKeys,
          tags: _messageTags,
          stackTrace: stackTrace,
        );
        break;
      case LogLevel.crash:
        FluxLogs.instance.crash(
          message,
          meta: _messageMetaKeys,
          tags: _messageTags,
          stackTrace: stackTrace,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Default meta', style: textStyle.titleLarge),
              KeyValueEditor(
                onChanged: (Map<String, String> value) {
                  for (String key in _defaultMeta.keys) {
                    FluxLogs.instance.removeMetaKey(key);
                  }
                  _defaultMeta.clear();
                  _setDefaultMetaDuration?.cancel();
                  _setDefaultMetaDuration = Timer(Duration(seconds: 1), () {
                    for (MapEntry<String, String> entry in value.entries) {
                      final String key = entry.key.trim();
                      final String value = entry.value.trim();
                      if (key.isEmpty && value.isEmpty) {
                        continue;
                      }
                      _defaultMeta[key] = value;
                      FluxLogs.instance.setMetaKey(key, value);
                    }
                  });
                },
              ),
              const SizedBox(height: 16.0),
              Text('Message options', style: textStyle.titleLarge),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  label: Text('Message'),
                  border: OutlineInputBorder(borderSide: BorderSide(width: 1)),
                ),
              ),
              const SizedBox(height: 8.0),
              TextField(
                onChanged: (val) {
                  final tags = val.split(',');
                  _messageTags.clear();
                  _messageTags.addAll(
                    tags.where((t) => t.trim().isNotEmpty).map((t) => t.trim()),
                  );
                },
                maxLines: 1,
                decoration: InputDecoration(
                  label: Text('Tags, delimiter \',\''),
                  border: OutlineInputBorder(borderSide: BorderSide(width: 1)),
                ),
              ),
              const SizedBox(height: 8.0),
              Text('Send StackTrace', style: textStyle.titleMedium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Send StackTrace?'),
                leading: Checkbox(
                  value: _sendStackTrace,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sendStackTrace = v;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              Text('LogLevel', style: textStyle.titleMedium),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: BoxBorder.fromBorderSide(BorderSide(width: 1)),
                ),
                child: DropdownButton<LogLevel>(
                  hint: Text('LogLevel'),
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  underline: SizedBox.shrink(),
                  isExpanded: true,
                  value: _logLevel,
                  items: LogLevel.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _logLevel = v;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              Text('Message meta keys', style: textStyle.titleMedium),
              KeyValueEditor(
                onChanged: (Map<String, String> value) {
                  _messageMetaKeys.clear();
                  for (MapEntry<String, String> entry in value.entries) {
                    final String key = entry.key.trim();
                    final String value = entry.value.trim();
                    if (key.isEmpty && value.isEmpty) {
                      continue;
                    }
                    _messageMetaKeys[key] = value;
                  }
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendEvent,
        tooltip: 'Send event',
        child: const Icon(Icons.send),
      ),
    );
  }
}
