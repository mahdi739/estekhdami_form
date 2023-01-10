import 'package:envied/envied.dart';

part 'values.g.dart';

@Envied()
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL', obfuscate: true)
  static const supabaseUrl = _Env.supabaseUrl;
  @EnviedField(varName: 'SUPABASE_KEY', obfuscate: true)
  static const supabaseKey = _Env.supabaseKey;
}
