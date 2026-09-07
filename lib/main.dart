import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF101211),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SupabaseClient? client;
  if (Backend.configured) {
    try {
      await Supabase.initialize(url: Backend.url, publishableKey: Backend.publishableKey);
      client = Supabase.instance.client;
    } catch (_) {
      // A build that cannot reach Supabase still runs: the football data is
      // bundled and ratings are stored on the device. Losing the server costs
      // the community, not the app.
      client = null;
    }
  }
  runApp(JuriApp(client: client));
}
