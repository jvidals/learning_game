import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> openParentGate(
  BuildContext context, {
  String purpose = 'open settings',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ParentGate(purpose: purpose),
    ) ??
    false;

class _ParentGate extends StatefulWidget {
  const _ParentGate({required this.purpose});
  final String purpose;
  @override
  State<_ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<_ParentGate> {
  final _answer = TextEditingController();
  final _a = Random().nextInt(7) + 3;
  final _b = Random().nextInt(7) + 3;
  bool _retry = false;
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_answer.text) == _a * _b) {
      Navigator.pop(context, true);
    } else {
      setState(() => _retry = true);
      _answer.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Grown-ups only'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ask a grown-up to help ${widget.purpose}.'),
          const SizedBox(height: 16),
          Text(
            '$_a × $_b = ?',
            key: const ValueKey('parent-challenge'),
            style: const TextStyle(fontSize: 26),
          ),
          TextField(
            controller: _answer,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              labelText: 'Answer',
              errorText: _retry ? 'Try again.' : null,
            ),
            onSubmitted: (_) => _check(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _check, child: const Text('Continue')),
    ],
  );
}
