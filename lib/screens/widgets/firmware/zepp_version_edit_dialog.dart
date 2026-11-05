import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zelp/domain/primitives/app_version.dart';

/// Asks for the official Zepp Play version name and versionCode.
Future<AppVersion?> showZeppVersionEditDialog(
  BuildContext context, {
  required AppVersion current,
}) => showDialog<AppVersion>(
  context: context,
  builder: (BuildContext context) => _ZeppVersionEditDialog(current: current),
);

class _ZeppVersionEditDialog extends StatefulWidget {
  const _ZeppVersionEditDialog({required this.current});

  final AppVersion current;

  @override
  State<_ZeppVersionEditDialog> createState() => _ZeppVersionEditDialogState();
}

class _ZeppVersionEditDialogState extends State<_ZeppVersionEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.current.displayName);
  late final TextEditingController _code = TextEditingController(
    text: widget.current.buildCode?.toString() ?? '',
  );
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.pop(
      context,
      AppVersion.play(name: _name.text, code: int.parse(_code.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Zepp app version'),
    content: Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            key: const Key('zepp-version-name'),
            controller: _name,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Version name',
              hintText: '10.10.5-play',
              helperText: 'Official Play version name',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('zepp-version-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Version code',
              hintText: '151997',
              helperText: 'Play versionCode for that name',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
            validator: _validateCode,
            onFieldSubmitted: (String _) => _submit(),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Save'),
      ),
    ],
  );
}

String? _validateName(String? raw) {
  final String name = raw?.trim() ?? '';
  if (!AppVersion.versionNamePattern.hasMatch(name)) {
    return 'Enter a Play version name such as 10.10.5-play';
  }
  return null;
}

String? _validateCode(String? raw) {
  final int? code = int.tryParse(raw?.trim() ?? '');
  if (code == null || code <= 0) {
    return 'Enter the numeric version code';
  }
  return null;
}
