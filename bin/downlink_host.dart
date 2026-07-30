import 'dart:io';

import 'package:downlink/src/native_host/native_host.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    switch (args.first) {
      case '--version':
      case '-v':
      case 'version':
        stderr.writeln('downlink-host dev');
        return;
      case '--help':
      case '-h':
      case 'help':
        stderr.writeln('downlink-host - native messaging bridge for Downlink');
        return;
    }
  }

  await NativeHost().run(stdin, stdout.add);
}
