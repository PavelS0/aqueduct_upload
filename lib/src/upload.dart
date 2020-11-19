import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:aqueduct/aqueduct.dart';
import 'package:mime/mime.dart';
import 'package:translit/translit.dart';
import 'package:path/path.dart' as path;

typedef String OnBeforeFileUpload(String first, String second);

class UploadFileParams {
  final String _filename;
  final String _name;
  Directory uploadDir;
  String uploadFileName;
  MimeMultipart data;
  bool preventDefault;
  UploadFileParams(this._filename, this._name);
}

class UploadField {
  String name;
  Future<String> getStringRepresentation() async {
    final list = await data.transform(utf8.decoder).toList();
    return list.join();
  }

  MimeMultipart data;
}

class UploadStatus {
  UploadStatus(this.code, this.status, {this.newName, this.oldName});
  int code;
  String status;
  String oldName;
  String newName;

  Map<String, dynamic> toJson() =>
      {'code': code, 'status': status, 'oldName': newName, 'newName': oldName};
}

class UploadController extends ResourceController {
  UploadController(this.dir) : this.fields = {} {
    acceptedContentTypes = [ContentType("multipart", "form-data")];
  }

  final defaultNameRegExp = RegExp(r'[^A-Za-z0-9\.-]');
  final Directory dir;
  final Map<String, UploadField> fields;

  static String _gibberish(int size) {
    const symb = "abcdefghijklmnpqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ123456789";
    const len = symb.length;
    final pass = StringBuffer();
    final rnd = Random();
    for (var i = 0; i < size; i++) {
      pass.write(symb[rnd.nextInt(len)]);
    }
    return pass.toString();
  }

  File _getFile(UploadFileParams f) {
    var filename = f.uploadFileName;
    final dir = f.uploadDir;
    File fw;
    if (dir != null && filename != null) {
      final dotIndex = filename.lastIndexOf('.');
      var ext = '';
      if (dotIndex > 0) {
        ext = filename.substring(dotIndex);
        filename = filename.substring(0, dotIndex);
      }
      fw = File(path.join(dir.path, '$filename$ext'));
      if (fw.existsSync()) {
        var giberrish = _gibberish(4);
        fw = File(path.join(dir.path, '$filename-$giberrish$ext'));
        if (fw.existsSync()) {
          giberrish = _gibberish(8);
          fw = File(path.join(dir.path, '$filename-$giberrish$ext'));
          if (fw.existsSync()) {
            fw = null;
          }
        }
      }
    }
    return fw;
  }

  Map<String, String> parseContentDispostition(String contentDisposition) {
    final parts = contentDisposition.split(';');
    final map = <String, String>{};
    if (parts.isNotEmpty) {
      final it = parts.iterator;
      it.moveNext();
      map['Content-Disposition'] = it.current.trim();
      while (it.moveNext()) {
        final par = it.current.split('=');
        if (par.length == 2) {
          final key = par[0].trim();
          var value = par[1].trim();
          value = value.substring(1, value.length - 1);
          map[key] = value;
        }
      }
    }
    return map;
  }

  @override
  FutureOr<RequestOrResponse> willProcessRequest(Request req) async {
    final raw = req.raw;
    if (raw.method == 'POST') {
      final boundary = raw.headers.contentType.parameters["boundary"];
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(raw).toList();

      final files = <UploadFileParams>[];
      for (var p in parts) {
        final contentDisposition =
            parseContentDispostition(p.headers["content-disposition"]);
        if (contentDisposition.containsKey('filename')) {
          final f = UploadFileParams(
              contentDisposition['filename'], contentDisposition['name']);
          f.uploadDir = dir;
          f.uploadFileName = Translit()
              .toTranslit(source: f._filename)
              .replaceAll(defaultNameRegExp, '-');
          f.preventDefault = false;
          f.data = p;
          files.add(f);
        } else if (contentDisposition.containsKey('name')) {
          final f = UploadField();
          f.data = p;
          f.name = contentDisposition['name'];
          fields[f.name] = f;
        }
      }

      final res = <UploadStatus>[];
      for (var f in files) {
        UploadStatus st;
        willFileSave(f._name, f._filename, f);
        if (!f.preventDefault) {
          final fw = _getFile(f);
          if (fw != null) {
            final sink = fw.openWrite();
            await sink.addStream(f.data);
            await sink.close();
            st = UploadStatus(0, 'Файл успешно загружен',
                newName: '/${dir.path}/${path.basename(fw.path)}',
                oldName: f._filename);
          } else {
            st = UploadStatus(1, 'Произошла ошибка во время загрузки файла');
          }
        }
        st = afterFileSave(st);
        res.add(st);
      }

      if (res.length == 1) {
        return Response.ok(res.first.toJson());
      } else {
        return Response.ok(res.map((e) => e.toJson()).toList());
      }
    } else {
      return Response(405, {}, null); // Method not allowed
    }
  }

  FutureOr<void> willFileSave(
    String name,
    String filename,
    UploadFileParams params,
  ) {}

  UploadStatus afterFileSave(UploadStatus st) => st;
}
