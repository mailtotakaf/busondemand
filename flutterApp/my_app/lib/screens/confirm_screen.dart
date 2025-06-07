import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';

final userPool = CognitoUserPool(
  'us-west-2_uoaxagXJ3',
  'lqtg505ssbpf9bo3dbr5halmi',
);

class ConfirmScreen extends StatefulWidget {
  final String email;
  ConfirmScreen({required this.email});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final _codeController = TextEditingController();
  String? _error;
  String? _message;

  Future<void> _confirm() async {
    try {
      final cognitoUser = CognitoUser(widget.email, userPool);
      final result = await cognitoUser.confirmRegistration(_codeController.text);
      setState(() {
        _error = null;
        _message = result == 'SUCCESS'
            ? '認証が完了しました！ログインしてください。'
            : '認証に失敗しました: $result';
      });
    } catch (e) {
      setState(() {
        _error = '認証に失敗しました: $e';
        _message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('確認コード入力')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('メールに届いた確認コードを入力してください'),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(labelText: '確認コード'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _confirm,
              child: Text('認証する'),
            ),
            if (_message != null) ...[
              SizedBox(height: 16),
              Text(_message!, style: TextStyle(color: Colors.green)),
            ],
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}