import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../../services/update_service.dart';
import '../widgets/setting_action_row.dart';

class AboutSettings extends StatefulWidget {
  final VoidCallback onMoveUp;
  final FocusNode? sidebarFocusNode;

  const AboutSettings({
    super.key,
    required this.onMoveUp,
    this.sidebarFocusNode,
  });

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  bool _isCheckingUpdate = false;
  String _currentVersion = '';
  final FocusNode _buttonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    final version = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _currentVersion = version);
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);

    final result = await UpdateService.checkForUpdate();

    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (result.error != null) {
      Fluttertoast.showToast(
        msg: result.error!,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
      return;
    }

    if (result.hasUpdate && result.updateInfo != null) {
      UpdateService.showUpdateDialog(
        context,
        result.updateInfo!,
        onUpdate: () {
          UpdateService.showDownloadProgress(context, result.updateInfo!);
        },
      );
    } else {
      Fluttertoast.showToast(
        msg: '已是最新版本',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingActionRow(
          label: '检查更新',
          value: '当前版本: $_currentVersion',
          buttonLabel: _isCheckingUpdate ? '检查中...' : '检查',
          autofocus: true,
          focusNode: _buttonFocusNode,
          isFirst: true,
          isLast: true,
          onMoveUp: widget.onMoveUp,
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isCheckingUpdate ? null : _checkForUpdate,
        ),
      ],
    );
  }
}
