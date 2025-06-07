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
  bool _isLoading = false; // ← 追加

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true; // ローディング開始
      _error = null;
    });
    try {
      final cognitoUser = CognitoUser(_emailController.text, userPool);
      final authDetails = AuthenticationDetails(
        username: _emailController.text,
        password: _passwordController.text,
      );
      final session = await cognitoUser.authenticateUser(authDetails);
      print(session?.getAccessToken()?.getJwtToken());
      setState(() => _isLoading = false); // ローディング終了

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RequestScreen(),
        ),
      );
    } catch (e) {
      print("login_screen Error: $e");
      String errorMsg = 'ログイン失敗';
      if (e is CognitoClientException && e.code == 'UserNotFoundException') {
        errorMsg = 'ユーザーが未登録です。新規登録してください。';
      }
      setState(() {
        _error = errorMsg;
        _isLoading = false; // ローディング終了
      });
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
            _isLoading
                ? CircularProgressIndicator() // ローディング中はインジケーター表示
                : ElevatedButton(onPressed: _signIn, child: Text('ログイン')),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
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
