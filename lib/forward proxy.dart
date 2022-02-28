import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_proxy/shelf_proxy.dart';

// https://stackoverflow.com/questions/44792707/angular-dart-how-to-create-a-proxy-server-for-angular-dart-apps

forwardProxy() async {
  handler(Request request) {
    String url = 'https://www.google.com/';
    final handler = proxyHandler(url, proxyName: '');
    print('Proxying at $url');
    return handler(request);
  }

  String host = '127.0.0.1';
  int port = 9080;
  HttpServer server = await serve(handler, host, port);
  print('启动代理转发服务器成功 $host $port');
}

customRequest(String url, Request request) {
  return new Request(request.method, Uri.parse(url),
      protocolVersion: request.protocolVersion,
      headers: request.headers,
      handlerPath: request.handlerPath,
      body: '',
      encoding: request.encoding,
      context: request.context);
}
