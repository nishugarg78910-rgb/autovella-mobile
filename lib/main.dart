import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/offline/response_cache.dart';
import 'core/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();

  // Reads fall back to this when the network is unavailable.
  final api = ApiClient.create()..cache = ResponseCache(prefs);

  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const AutovellaApp(),
    ),
  );
}
