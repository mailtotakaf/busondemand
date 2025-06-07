import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:my_app/screens/confirm_screen.dart';
import 'signup_screen.dart'; // ← 追加
import 'request_screen.dart'; // 追加
import 'package:flutter_dotenv/flutter_dotenv.dart';

final userPool = CognitoUserPool(
  dotenv.env['COGNITO_USER_POOL_ID']!,
  dotenv.env['COGNITO_CLIENT_ID']!,
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

      // ログイン成功時にRequestScreenへ遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RequestScreen()),
      );
    } catch (e) {
      print("login_screen Error: $e");
      setState(() => _error = 'ログイン失敗');
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
            ElevatedButton(onPressed: _signIn, child: Text('ログイン')),
            TextButton(
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => SignUpScreen()),
                // );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ConfirmScreen(email: _emailController.text),
                  ),
                );
              },
              child: Text('新規登録はこちら'),
            ),
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
