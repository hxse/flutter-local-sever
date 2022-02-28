// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

String configDefault = '''{
    "rootPath": "cache-data-dir"
}
''';
fetchConfig() async {
  final String response = await rootBundle.loadString('assets/config.json');
  return await json.decode(response);
}

defaultConfig() async {
  print('defaultConfig');
  File file = File('config.json');
  if ((await file.exists()) == false) {
    writeConfig(configDefault);
  }
}

resetConfig() async {
  print('resetConfig');
  File file = File('config.json');
  if ((await file.exists()) == true) {
    await file.delete();
  }
  await defaultConfig();
}

readConfig() async {
  File file = File('config.json');
  String response = await file.readAsString();
  dynamic jsonData = await json.decode(response);
  // if (jsonData['rootPath'] != 'dataDir') {
  //   throw '本地缓存目录名设置错误';
  // }
  return jsonData;
}

writeConfig(String content) async {
  // 示例写法: await writeConfig(json.encode(jsonData));

  File file = File('config.json');
  await file.writeAsString(content);
}

typedef DataMap = Map<String, dynamic>;
typedef DataMapNest = DataMap;
typedef DataMapList = List<DataMap>;
typedef Opt = Map<String, bool>;

checkType(String path) async {
  //返回以下几种之一: file, dir, need-file, need-dir
  if (!path.startsWith('data/')) {
    // throw FileSystemException('路径要以/data/开头,$path');
  }

  loopCheckParent(File file) async {
    //父文件夹不可以是file,file怎么能做文件夹呢
    getSegmentLength(Uri uri) => uri.pathSegments.where((i) => i != '').length;
    dynamic parent = file.parent;
    while (true) {
      File parentFile = File(parent.path);
      final parentFileExists = await parentFile.exists();
      if (parentFileExists == true) {
        throw FileSystemException('父文件夹不可以是file,请检查路径: ${parent.path}');
      }
      if (getSegmentLength(parent.uri) == 1) break;
      parent = parent.parent;
    }
  }

  await loopCheckParent(File(path));

  if (path[path.length - 1] == '/') {
    try {
      Directory dir = Directory(path);
      final dirExists = await dir.exists();
      if (dirExists) return 'dir';
    } on FileSystemException catch (e) {
      print(e);
      File file = File(path);
      final fileExists = await file.exists();
      if (fileExists == false) {
        throw const FileSystemException('文件不要加斜杠');
      }
    }
    return 'need-dir';
  } else {
    Directory dir = Directory(path);
    final dirExists = await dir.exists();
    if (dirExists) {
      throw const FileSystemException('文件夹要加斜杠');
    }
    File file = File(path);
    final fileExists = await file.exists();
    if (fileExists) return 'file';
    return 'need-file';
  }
}

Map<String, bool> newOption(
    List<String> requestPara, Map<String, bool> option) {
  Map<String, bool> newOption = {};
  for (String i in option.keys) {
    newOption[i] = requestPara.contains(i) ? true : false;
  }
  return newOption;
}

DataMapNest getQuery(DataMapNest firstQuery, DataMapNest laterQuery) {
  DataMapNest query = {};
  for (final element in firstQuery.values) {
    element['later'] = false; // 直接运行
  }
  for (final element in laterQuery.values) {
    element['later'] = true; // 放后面运行
  }
  query = {...firstQuery, ...laterQuery};
  return query;
}

Future<DataMap> readFile(File file, Map<String, bool> option) async {
  DataMap obj = {};
  DataMapNest query = {}; //可以闭包使用query
  DataMapNest firstQuery = {
    // 直接运行的放在这里
    'get-content': {
      'case': [option['get-content']],
      'act': () async => await file.readAsString(),
    },
    'get-size': {
      'case': [option['get-size']],
      'act': () async => await file.length(),
    }
  };
  DataMapNest laterQuery = {
    // 需要依赖才能运行的放在这里
    'get-length': {
      'case': [option['get-length']],
      'act': () async {
        if (obj.containsKey('get-content')) {
          print('获取缓存');
          return obj['get-content']!.length;
        } else {
          print('重新计算');
          final content = await query['get-content']!['act']();
          return content.length;
        }
      },
      'later': true
    }
  };
  query = getQuery(firstQuery, laterQuery);
  for (bool bl in [true, false]) {
    for (String i in query.keys) {
      if (query[i]?['later'] == bl) continue;
      if (query[i]?['case'].every((i) => i == true) == true) {
        obj[i] = await query[i]?['act']();
      }
    }
  }

  obj = {
    'name': file.uri.pathSegments.last,
    'parent': file.parent.path + Platform.pathSeparator,
    'path': file.path,
    'isAbsolute': file.isAbsolute,
    'type': 'file',
    ...obj
  };
  print(['read file:', obj]);
  return obj;
}

Future<DataMap> read(String path, Map<String, bool> option) async {
  //读取文件
  File file = File(path);
  DataMap obj = await readFile(file, option);
  return obj;
}

getDirInfo(String dirPath, List dirList, Map<String, bool> option) async {
  //不会递归计算,get文件夹的当前大小
  DataMap obj = {};
  final dir = Directory(dirPath);
  final dirList = await dir.list(recursive: false).toList();

  DataMapNest query = {}; //可以闭包使用query
  DataMapNest firstQuery = {
    'dir-child': {
      'case': [option['dir-child']],
      'act': () async {
        List<String> arr = [];
        for (FileSystemEntity element in dirList) {
          arr.add(element.uri.toFilePath());
        }

        return arr;
      }
    },
    'dir-child-num': {
      'case': [option['dir-child-num']],
      'act': () async {
        num fileNum = 0;
        num dirNum = 0;
        for (FileSystemEntity element in dirList) {
          String type = element.uri.pathSegments.last == '' ? 'dir' : 'file';
          if (type == 'file') {
            fileNum++;
          } else {
            dirNum++;
          }
        }
        return {'fileNum': fileNum, 'dirNum': dirNum};
      },
    },
    'dir-size': {
      'case': [option['dir-size']],
      'act': () async {
        num size = 0;
        for (FileSystemEntity element in dirList) {
          String type = element.uri.pathSegments.last == '' ? 'dir' : 'file';
          if (type == 'file') {
            String path = element.uri.toFilePath();
            DataMap fileData =
                await read(path, newOption(['get-size'], option));
            print(fileData);
            size = size + fileData['get-size'];
          }
        }
        return size;
      },
    }
  };
  DataMapNest laterQuery = {};
  query = getQuery(firstQuery, laterQuery);
  for (bool bl in [true, false]) {
    for (String i in query.keys) {
      if (query[i]?['later'] == bl) continue;
      if (query[i]?['case'].every((i) => i == true) == true) {
        obj[i] = await query[i]?['act']();
      }
    }
  }
  return {
    'name': dir.uri.pathSegments[dir.uri.pathSegments.length - 2],
    'parent': dir.parent.path + Platform.pathSeparator,
    'path': dirPath,
    'isAbsolute': dir.isAbsolute,
    'type': 'dir',
    ...obj
  };
}

Future<DataMapList> readDir(String filePath, Map<String, bool> option) async {
  //读取文件夹
  final dir = Directory(filePath);
  final dirList = await dir.list(recursive: option['recursive']!).toList();
  DataMapList data = [];
  for (FileSystemEntity element in dirList) {
    String path = element.uri.toFilePath();
    List<String> fileSegments = element.uri.pathSegments;
    String type = fileSegments.last == '' ? 'dir' : 'file';
    DataMap infoObj = {};
    switch (type) {
      case 'file':
        infoObj = await read(path, option);
        break;
      case 'dir':
        infoObj = await getDirInfo(path, dirList, option);
        break;
    }
    data.add(infoObj);
  }
  print(['read file:', dirList]);
  return data;
}

readDirSize(String path) async {
  //读取文件夹大小
  final dir = Directory(path);
  final content = await dir.list().toList();
  int size = 0;
  for (FileSystemEntity f in content) {
    if (f is File) {
      size = size + await f.length();
      print([f, size]);
    }
  }
  print(['read file:', content]);
  return size;
}

Future<DataMap> write(
    String path, Map<String, bool> option, String content) async {
  //写入文件

  String rootPath = await getRootPath();
  String partPath = replacePath(path, rootPath);

  File file = await File(path).create(recursive: true);
  File newFile = await file.writeAsString(content);
  print('write file:$newFile');
  DataMap obj = await readFile(newFile, option);
  return obj;
}

createDir(String path) {
  final dir = Directory(path);
  dir.create(recursive: true);
  return dir.uri;
}

remove(String path) async {
  //删除文件
  File file = File(path);
  await file.delete();
  print(['delete file:', file]);
  return;
}

removeDir(String path) async {
  //删除文件夹
  Directory dir = Directory(path);
  await dir.delete(recursive: true);
  print(['delete dir:', dir]);
  return;
}

formData(HttpRequest request, String path, Map<String, bool> option) async {
  //参考https://www.youtube.com/watch?v=hSkD3y9HMro
  //https://gist.github.com/graphicbeacon/c25ffe49dade93003742bc43cc21147b
  //https://stackoverflow.com/questions/54965027/how-can-i-write-uploaded-multipart-files-to-disk
  getBytes() async* {
    await for (final l in request) {
      yield l;
    }
  }

  final transformer = MimeMultipartTransformer(
      request.headers.contentType!.parameters["boundary"]!);
  final myBytes = getBytes();
  final parts = transformer.bind(myBytes);

  await for (final part in parts) {
    writePart(part, path, option);
  }
}

writePart(MimeMultipart part, String urlPath, Map<String, bool> option) async {
  String contentDisposition = part.headers['content-disposition']!;
  final fileName = RegExp(r'filename="([^"]*)"')
      .firstMatch(contentDisposition)
      ?.group(1)
      ?.trim();
  final name = RegExp(r'name="([^"]*)"')
      .firstMatch(contentDisposition)
      ?.group(1)
      ?.trim();

  if (option['form-data-multiple'] == true) {
    //这个不写了,别用,因为改动太大了, 还得把route.dart里的pathType,不好兼容
    urlPath = '${urlPath.split('/')[0]}/$name'; // '$rootPath/$name $fileName';
  }

  Stream<List<int>?> chunkStream() async* {
    await for (List<int> i in part) {
      yield i;
    }
    return;
  }

  await chunkAppendFile(urlPath, chunkStream());
}

Future<String> getRootPath() async {
  try {
    final jsonData = await readConfig();
    if (jsonData['rootPath'] == '' || jsonData['rootPath'] == null) {
      throw "config.json,rootPath字段不能为空";
    }
    return jsonData['rootPath'];
  } catch (e) {
    print(e);
    await resetConfig();
    final jsonData = await readConfig();
    return jsonData['rootPath'];
  }
}

stripSlash(String urlPath) {
  return urlPath.startsWith('/') ? urlPath.substring(1) : urlPath;
}

String replacePath(String urlPath, String rootPath) {
  return '$rootPath/${stripSlash(urlPath).split('/').sublist(1).join('/')}';
}

Stream<List<int>?> chunkIterable(Stream<int?> interable,
    {int size = 1024 * 1024 * 5}) async* {
  List<int> data = [];
  await for (int? b in interable) {
    if (b == null) break;
    data.add(b);
    if (data.length >= size) {
      yield data;
      data = [];
    }
  }
  if (data.isNotEmpty) {
    yield data;
  }
  return;
}

chunkAppendFile(String urlPath, Stream<List<int>?> content,
    {bool over = true}) async {
  File file = File(urlPath);
  await file.create(recursive: true);
  if (over == true) {
    await file.writeAsBytes([]);
  }
  //不在for循环外面用openWrite的话,可能会导致锁冲突
  print('打开文件: $file');
  IOSink sink = file.openWrite(mode: FileMode.writeOnlyAppend);
  await for (List<int>? c in content) {
    if (c == null) break;
    sink.add(c); //bytes要用add方法,字符串用write方法
    // await sink.flush();
  }
  await sink.close();
  print('关闭文件: $file');
}

Future<DataMap> mergeFile(
    String path, String content, Map<String, bool> option) async {
  String rootPath = await getRootPath();
  final jsonData = json.decode(content);
  print('查看 $jsonData');
  // print('查看 ${jsonData["name"]}');

  genIntIterable() async* {
    //这个弃用,性能简直是灾难,即使改成同步也差强人意,只是稍好一些,直接读取part就完事了
    for (Map l in jsonData['chunkList']) {
      String partPath = replacePath(l['name'], rootPath);
      File partFile = File(partPath);
      List<int> bytes = await partFile.readAsBytes();
      for (int i in bytes) {
        yield i;
      }
    }
    return;
  }

  Stream<int?> bytes = genIntIterable();
  // Stream<List<int>?> chunkStream = chunkIterable(bytes);

  Stream<List<int>?> chunkStream() async* {
    for (final obj in jsonData['chunkList']) {
      String partPath = replacePath(obj['name'], rootPath);
      File partFile = File(partPath);
      List<int> bytes = await partFile.readAsBytes();
      yield bytes;
    }
    return;
  }

  await chunkAppendFile(path, chunkStream());

  if (option['merge-clean-part'] == true) {
    for (final obj in jsonData['chunkList']) {
      String partPath = replacePath(obj['name'], rootPath);
      File partFile = File(partPath);
      await partFile.delete();
    }
  }

  if (option['merge-clean-dir'] == true) {
    if (jsonData['chunkList'].length > 0) {
      Directory parentDir =
          Directory(replacePath(jsonData['chunkList'][0]['name'], rootPath))
              .parent;
      if (parentDir.uri.pathSegments.where((i) => i != '').toList().length >=
          2) {
        print(parentDir);
        await parentDir.delete();
      }
    }
  }
  return await readFile(File(path), option);
}
