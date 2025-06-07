import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';

final userPool = CognitoUserPool(
  'us-west-2_uoaxagXJ3',
  'lqtg505ssbpf9bo3dbr5halmi',
);

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  Future<void> _signIn() async {
    try {
      final cognitoUser = CognitoUser(_emailController.text, userPool);
      final authDetails = AuthenticationDetails(
        username: _emailController.text,
        password: _passwordController.text,
      );
      final session = await cognitoUser.authenticateUser(authDetails);
      print(session?.getAccessToken()?.getJwtToken());
      setState(() => _error = null);
      // ログイン成功時の画面遷移など
    } catch (e) {
      setState(() => _error = 'ログイン失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('ログイン'),
            ),
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}