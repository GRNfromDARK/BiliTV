import 'package:shared_preferences/shared_preferences.dart';

class PluginStore {
  static const String _prefix = 'plugin_enabled_';

  /// 保存插件启用状态
  static Future<void> setEnabled(String pluginId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$pluginId', enabled);
  }

  /// 获取插件启用状态
  static Future<bool> isEnabled(
    String pluginId, {
    bool defaultValue = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$pluginId') ?? defaultValue;
  }
}
