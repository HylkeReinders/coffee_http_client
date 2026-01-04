import 'dart:convert';

import 'package:coffee_http_client/coffee_http_client.dart';
import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  CoffeeHttp.configure(
    CoffeeHttpConfig(
      baseUrl: CoffeeUri(
        host: 'jsonplaceholder.typicode.com',
        scheme: CoffeeHttpScheme.https,
      ),
      headersBuilder: (request) {
        // Example: attach headers based on request tags
        if (request.tags.contains('auth')) {
          return {'Authorization': 'Bearer fake-token'};
        }

        return {};
      },
      hooks: CoffeeHooks(
        onResponse: (CoffeeResponseContext ctx) {
          debugPrint(
            '[HTTP] ${ctx.request.method.name.toUpperCase()} '
            '${ctx.request.path} → ${ctx.response.statusCode} '
            '(${ctx.response.duration.inMilliseconds}ms)',
          );
        },
        onError: (CoffeeErrorContext ctx) {
          debugPrint('[HTTP ERROR] ${ctx.request.path} → ${ctx.error.kind}');
        },
        handleResponse: (CoffeeHandleResponseContext ctx) {
          final res = ctx.response;

          final isSuccess = ctx.forceStatusCode != null
              ? res.statusCode == ctx.forceStatusCode
              : res.statusCode >= 200 && res.statusCode < 300;

          if (!isSuccess) {
            throw Exception('Request failed with status ${res.statusCode}');
          }

          if (res.body.isEmpty) return null;

          return jsonDecode(res.body);
        },
      ),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const ExampleScreen());
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  bool _loading = false;
  String _output = '';

  Future<void> _loadPost() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    try {
      final data = await CoffeeHttp.instance.getHandled<Map<String, dynamic>>(
        '/posts/1',
        name: 'posts.single',
        tags: {'public'},
      );

      setState(() {
        _output = const JsonEncoder.withIndent('  ').convert(data);
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('coffee_http example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _loadPost,
              child: const Text('Load example request'),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _output.isEmpty
                      ? 'Press the button to execute a request.'
                      : _output,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
