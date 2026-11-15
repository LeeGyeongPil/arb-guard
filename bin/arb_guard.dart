import 'dart:io';

import 'package:arb_guard/src/cli.dart';

Future<void> main(List<String> args) async {
  try {
    exitCode = await runCli(args);
    await stdout.flush();
  } on IOException catch (e) {
    // The reader closed the pipe early (`arb_guard check | head`): stop quietly.
    if (_isBrokenPipe(e)) return;
    rethrow;
  }
}

bool _isBrokenPipe(IOException e) {
  final code = switch (e) {
    FileSystemException(:final osError) => osError?.errorCode,
    SocketException(:final osError) => osError?.errorCode,
    _ => null,
  };
  // 32 = EPIPE on Linux and macOS, 232/109 = closed pipe on Windows.
  return code == 32 || code == 232 || code == 109;
}
