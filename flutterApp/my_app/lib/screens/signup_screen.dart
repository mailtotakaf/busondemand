import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'confirm_screen.dart';

final userPool = CognitoUserPool(
  'us-west-2_uoaxagXJ3',
  'lqtg505ssbpf9bo3dbr5halmi',
);

class SignUpScreen extends StatefulWidget {
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  String? _message;

  Future<void> _signUp() async {
    try {
      final userAttributes = [AttributeArg(name: 'email', value: _emailController.text)];
      final result = await userPool.signUp(
        _emailController.text,
        _passwordController.text,
        userAttributes: userAttributes,
      );
      setState(() {
        _error = null;
        _message = 'サインアップ成功！メールを確認してください。';
      });
      if (result.userConfirmed == false) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmScreen(email: _emailController.text),
          ),
        );
      }
    } catch (e) {
      setState(() {
        print("signup_screen Error: $e");
        String errorMsg = 'サインアップ失敗';
        if (e is CognitoClientException && e.code == 'UsernameExistsException') {
          errorMsg = 'User already exists.';
        }
        _error = errorMsg;
        _message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('サインアップ')),
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
            ElevatedButton(onPressed: _signUp, child: Text('サインアップ')),
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