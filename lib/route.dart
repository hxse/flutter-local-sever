// ignore_for_file: avoid_print
import 'file_io.dart';
import 'dart:io';

DataMap checkBodySize(DataMap resText, int bodyMaxSize, HttpRequest request) {
  DataMap newResText = {...resText, 'route': 'checkBodySize'};
  if (request.contentLength > bodyMaxSize) {
    return {
      'res': null,
      'err': {
        ...newResText,
        "message": "太大了,请切分上传",
        "code": 200,
        "length": request.contentLength
      }
    };
  }
  print('上传大小: ${request.contentLength} 小于限制大小 $bodyMaxSize');
  return {'res': request.contentLength, 'err': null};
}

Opt checkParaBool(Map<String, bool> requiredPara, HttpRequest request) {
  Opt obj = {};
  for (String para in requiredPara.keys) {
    judge() {
      if (request.uri.queryParameters.containsKey(para) == true) {
        return ['true', 'True'].contains(request.uri.queryParameters[para])
            ? true
            : false;
      } else {
        return requiredPara[para]!;
      }
    }

    obj[para] = judge();
    // obj[para] = [
    //   request.uri.queryParameters.containsKey(para),
    //   ['true', 'True'].contains(request.uri.queryParameters[para])
    // ].every((i) => i == true);
  }
  return obj;
}

Future<DataMap> checkTypeExists(
  DataMap resText,
  HttpRequest request,
  String path,
) async {
  DataMap newResText = {...resText, 'route': 'checkTypeExists'};
  try {
    String type = await checkType(path);
    return {'res': type, 'err': null};
  } on FileSystemException catch (e) {
    print(e);
    return {
      'res': null,
      'err': {
        ...newResText,
        "message": e.message,
        "code": 503,
        "url": request.requestedUri,
      }
    };
  }
}

checkParaListExists(List<String> requiredPara, HttpRequest request) {
  for (String para in requiredPara) {
    if (!request.uri.queryParameters.containsKey(para)) {
      throw Exception('missing <$para> parameters');
    }
  }
}

DataMap checkParaExists(String para, DataMap resText, HttpRequest request) {
  DataMap newResText = {...resText, 'route': 'checkParaExists'};
  try {
    checkParaListExists([para], request);
    return {'res': request.uri.queryParameters[para]!, 'err': null};
  } on Exception catch (e) {
    print(e);
    return {
      'res': null,
      'err': {
        ...newResText,
        "message": e,
        "code": 400,
      }
    };
  }
}

Future<DataMap> switchPathType(String pathType, DataMapNest obj) async {
  //pathType 有几种类型: file, dir, need-file, need-dir
  final data = await obj[pathType]!['act']();
  return obj[pathType]!['res'](data);
}

Future<DataMap> postRead(
    DataMap resText, String path, String pathType, Opt option) async {
  DataMap newResText = {...resText, 'route': 'postRead'};
  return await switchPathType(pathType, {
    'file': {
      'act': () async => await read(path, option),
      'res': (data) =>
          {...newResText, "message": "成功读取文件", "code": 200, "data": data}
    },
    'dir': {
      'act': () async => await readDir(path, option),
      'res': (data) =>
          {...newResText, "message": "成功读取目录", "code": 200, "data": data}
    },
    'need-file': {
      'act': () async => null,
      'res': (data) => {
            ...newResText,
            "message": "读取失败,目标不存在",
            "code": 404,
          }
    },
    'need-dir': {
      'act': () async => null,
      'res': (data) => {
            ...newResText,
            "message": "读取失败,目标不存在",
            "code": 404,
          }
    }
  });
}

Future<DataMap> postUpdateFormData(
  DataMap resText,
  HttpRequest request,
  String path,
  Map<String, bool> option,
  String pathType,
) async {
  DataMap newResText = {...resText, 'route': 'postUpdateFormData'};

  return await switchPathType(pathType, {
    'file': {
      'act': () async => await formData(request, path, option),
      'res': (data) => {"message": "成功更新二进制文件", "code": 200, "data": data}
    },
    'dir': {
      'act': () async => await readDir(path, option),
      'res': (data) => {
            ...newResText,
            "message": "目录无法更新",
            "code": 501,
          }
    },
    'need-file': {
      'act': () async => await formData(request, path, option),
      'res': (data) => {
            ...newResText,
            "message": "成功创建文件,并更新二进制文件",
            "code": 200,
          }
    },
    'need-dir': {
      'act': () async => null,
      'res': (data) => {
            ...newResText,
            "message": "想创建目录?,请不要用form-data,不带body即可",
            "code": 500,
          }
    }
  });
}

Future<DataMap> postUpdateText(DataMap resText, String pathType, String path,
    Opt option, String content) async {
  DataMap newResText = {...resText, 'route': 'postUpdateText'};
  return await switchPathType(pathType, {
    'file': {
      'act': () async => await write(path, option, content),
      'res': (data) => {"message": "成功更新文件", "code": 200, "data": data}
    },
    'dir': {
      'act': () async => await readDir(path, option),
      'res': (data) => {
            ...newResText,
            "message": "目录无法更新",
            "code": 501,
          }
    },
    'need-file': {
      'act': () async => await write(path, option, content),
      'res': (data) => {
            ...newResText,
            "message": "成功创建文件",
            "code": 200,
          }
    },
    'need-dir': {
      'act': () async => createDir(path),
      'res': (data) => {
            ...newResText,
            "message": "成功创建目录",
            "code": 200,
          }
    }
  });
}

Future<DataMap> tryMerge(String path, DataMap resText, HttpRequest request,
    String content, Opt option) async {
  DataMap newResText = {...resText, 'route': 'tryMerge'};
  try {
    DataMap data = await mergeFile(path, content, option);
    return {
      ...newResText,
      "message": "合并完毕, $data",
      "code": 200,
    };
  } on FileSystemException catch (e) {
    return {
      ...newResText,
      "message": e,
      "code": 500,
    };
  }
}

Future<DataMap> postUpdateMerge(
  DataMap resText,
  HttpRequest request,
  String pathType,
  String path,
  Opt option,
  String content,
) async {
  DataMap newResText = {...resText, 'route': 'postUpdateMerge'};
  Future<DataMap> actTryMerge() async {
    return await tryMerge(path, resText, request, content, option);
  }

  return await switchPathType(pathType, {
    'file': {
      'act': actTryMerge,
      'res': (DataMap data) => {...newResText, ...data}
    },
    'dir': {
      'act': () async => null,
      'res': (DataMap data) => {
            "message": "请指定文件路径,而不是文件夹",
            "code": 500,
          }
    },
    'need-file': {
      'act': actTryMerge,
      'res': (DataMap data) => {...newResText, ...data}
    },
    'need-dir': {
      'act': null,
      'res': (data) => {
            ...newResText,
            "message": "想创建文件夹?直接创建即可,不用携带body体",
            "code": 500,
          }
    }
  });
}

Future<DataMap> postDelete(
  DataMap resText,
  String pathType,
  String path,
) async {
  DataMap newResText = {...resText, 'route': 'postDelete'};
  return await switchPathType(pathType, {
    'file': {
      'act': () async => await remove(path),
      'res': (data) => {...newResText, "message": "成功删除文件", "code": 200}
    },
    'dir': {
      'act': () async => await removeDir(path),
      'res': (data) => {...newResText, "message": "成功删除目录", "code": 200}
    },
    'need-file': {
      'act': () async => null,
      'res': (data) => {...newResText, "message": "目标不存在,删除失败", "code": 404}
    },
    'need-dir': {
      'act': () async => null,
      'res': (data) => {...newResText, "message": "目标不存在,删除失败", "code": 404}
    }
  });
}
