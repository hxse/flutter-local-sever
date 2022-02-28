// ignore_for_file: avoid_print

import 'package:flutter/cupertino.dart';
import 'file_io.dart';
import 'dart:io';
import 'route.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/adapter.dart';

setProxy(String proxy, Dio dio) {
  //proxy: 'PROXY 127.0.0.1:7890', "DIRECT"
  (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
      (client) {
    // config the http client
    client.findProxy = (uri) {
      //proxy all request to localhost:8888
      // return "DIRECT";
      return proxy;
    };
    // you can also create a HttpClient to dio
    // return HttpClient();
  };
}

allowCors(HttpResponse response) {
  response.headers.add("Access-Control-Allow-Headers", "*");
  response.headers.add("Access-Control-Allow-Origin", "*");
  response.headers
      .add("Access-Control-Allow-Methods", "POST,GET,DELETE,PUT,OPTIONS");
}

myHttp(ValueNotifier testText, ValueNotifier counter,
    {String localUrl = '127.0.0.1', int port = 8881}) {
  http() {
    print('文件服务器启动成功 $localUrl $port');
    HttpServer.bind(localUrl, port).then((HttpServer server) {
      server.listen((HttpRequest request) async {
        print('接受到请求');
        print(request.method);
        print(request.requestedUri);
        print(request.uri.host);
        print('request.uri.path $request.uri.path');
        print(request.uri.queryParameters);
        print(request.contentLength);

        HttpResponse response = request.response;

        Opt option = checkParaBool({
          'get-content': false,
          'get-size': false,
          'get-length': false,
          'recursive': false,
          'dir-size': false,
          'dir-child': false,
          'dir-child-num': false,
          'merge': false,
          'merge-clean-part': true,
          'merge-clean-dir': false,
        }, request);
        DataMap resText = {
          "message": "",
          "code": null,
          "type": null,
          "data": null,
          'separator': Platform.pathSeparator
        };

        myProxy() async {
          // https://stackoverflow.com/questions/44792707/angular-dart-how-to-create-a-proxy-server-for-angular-dart-apps
          // https://github.com/flutterchina/dio/blob/master/README-ZH.md

          BaseOptions options = BaseOptions(
            // connectTimeout: 5000,
            // receiveTimeout: 3000,
            responseType: null,
            // responseType: ResponseType.json,//ResponseType.index: 0=>json,1=>stream,2=>plain,3=>bytes
          );
          Dio dio = Dio(options);

          setProxy('PROXY 127.0.0.1:7890', dio);

          // Response res = await dio.get('https://i.imgur.com/ZQd82bC.jpg');
          final paraObj = checkParaExists('url', resText, request);
          if (paraObj['err'] != null) {
            response.write(paraObj['err']);
            return response.close();
          }
          String url = paraObj['res'];
          print(url);

          Response res = await dio.get(url);
          print(res.statusCode);

          response.headers.clear();
          res.headers.forEach((name, values) {
            if (!['content-length', 'connection'].contains(name)) {
              // response.headers.set(name, values);
            }
            if (['content-type'].contains(name)) {
              response.headers.set(name, values);
            }
          });
          allowCors(response);

          // print('response content-type: ${response.headers['content-type']}');
          print('response content-type: ${response.headers}');
          switch (response.headers['content-type']?[0]) {
            case "application/json":
              // response.write('${res.data}');
              response.write(res.data);
              break;
            case '': //plain
              response.write(res.data);
              break;
            case '': //bytes
              response.add(res.data);
              break;
            case '': //stream
              response.addStream(res.data.stream);
              break;
            default:
          }
          // File image = new File("C:\\Users\\hxse\\Downloads\\ZQd82bC.jpg");
          // final img = await image.readAsBytes();
          // response.add(img);
        }

        if (request.uri.path == '/proxy') {
          await myProxy();
          return response.close();
        }

        Future<DataMap> mypost(String urlPath) async {
          int bodyMaxSize = 1024 * 1024 * 320; //1024*1024=1M
          DataMap bodyObj = checkBodySize(resText, bodyMaxSize, request);
          if (bodyObj['err'] != null) return bodyObj['err'];

          DataMap typeObj = await checkTypeExists(resText, request, urlPath);
          if (typeObj['err'] != null) return typeObj['err'];
          String pathType = typeObj['res'];
          resText['type'] = pathType;
          print(pathType);

          if (request.method == "POST") {
            DataMap paraObj = checkParaExists('method', resText, request);
            if (paraObj['err'] != null) return paraObj['err'];
            String method = paraObj['res'];

            switch (method) {
              case 'read':
                return await postRead(resText, urlPath, pathType, option);
              case 'update':
                String? contentType = request.headers.contentType?.value;
                print('contentType: $contentType');
                switch (contentType) {
                  case 'text/plain':
                  case 'application/json':
                    String content = await utf8.decoder.bind(request).join();
                    if (option['merge'] == true) {
                      return await postUpdateMerge(
                          resText, request, pathType, urlPath, option, content);
                    } else {
                      return await postUpdateText(
                          resText, pathType, urlPath, option, content);
                    }
                  case 'multipart/form-data':
                    return await postUpdateFormData(
                        resText, request, urlPath, option, pathType);
                  default:
                    return {
                      ...resText,
                      "message": 'contentType unknown $contentType',
                      "code": 500,
                    };
                }
              case 'delete':
                return await postDelete(resText, pathType, urlPath);
              default:
                return {
                  ...resText,
                  "message": 'method unknown $method',
                  "code": 500,
                };
            }
          }
          return resText;
        }

        myRoute() async {
          String rootPath = await getRootPath();
          if (request.uri.path == '/config.json') {
            String urlPath = 'config.json';
            return await mypost(urlPath);
          } else {
            if (request.uri.path.split('/')[1] != 'data') {
              return {
                "message": '不支持的root目录 ${request.uri.path.split('/')[1]}',
                "code": 500,
              };
            }
            String urlPath = replacePath(request.uri.path, rootPath);
            return await mypost(urlPath);
          }
        }

        DataMap resText_ = await myRoute();
        allowCors(response);
        response.write(resText_);
        return response.close();
      });
    });
  }

  return http;
}
