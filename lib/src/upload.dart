import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:aqueduct/aqueduct.dart';
import 'package:mime/mime.dart';
import 'package:translit/translit.dart';
import 'package:path/path.dart' as path;

class UploadController extends ResourceController {

  UploadController(this.dir) {
    acceptedContentTypes = [ContentType("multipart", "form-data")];
  }

  final Directory dir;

  static String _gibberish(int size) {
    const symb =  "abcdefghijklmnpqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ123456789";
    const len = symb.length;
    final pass = StringBuffer();
    final rnd = Random();
    for (var i = 0; i < size; i++){
      pass.write(symb[rnd.nextInt(len)]);
    }
    return pass.toString();
  }

  File _getFile(String filename, String ext) {
    var fw = File(path.join(dir.path, '$filename$ext'));
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
    return fw;
  }

  @override
  FutureOr<RequestOrResponse>  willProcessRequest(Request req) async {
    final raw = req.raw;
    if (raw.method == 'POST') {
      final res = <String, dynamic> {};
      final boundary = raw.headers.contentType.parameters["boundary"];
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(raw).toList();

      final filePart = parts.firstWhere((part)=>part.headers["content-disposition"].contains("filename"));
    
      final fileRegexp = RegExp(r'filename="(.*)"');
      final nameRegexp = RegExp(r'[^A-Za-z0-9\.-]');
      final fn = fileRegexp.firstMatch(filePart.headers['content-disposition']).group(1);
      final fullfn = Translit().toTranslit(source: fn).replaceAll(nameRegexp, '-');
      
      final dotIndex = fullfn.lastIndexOf('.');
      String ext = '';
      if (dotIndex >= 0 ) {
        ext = fullfn.substring(dotIndex);
      }
      final filename = fullfn.substring(0, dotIndex > 0 ? dotIndex : null);
      final content = await filePart.toList();
      final fw = _getFile(filename, ext);
      if (fw != null) {
        final sink = fw.openWrite();
        content.forEach(sink.add);
        await sink.close();
        res['code'] = 0;
        res['status'] = 'Файл успешно загружен';
        res['oldName'] = fn;
        res['newName'] = '/${dir.path}/${path.basename(fw.path)}';
      } else {
        res['status'] = 'Не удалось создать файл';
        res['code'] = -1;
      }
      return Response(200, {}, res);
    } else {
      return Response(405, {}, null);// Method not allowed
    }
  }


 /*  @Operation.post()
  Future<Response> postForm() async {
    final res = <String, dynamic> {};

    final boundary = request.raw.headers.contentType.parameters["boundary"];
    final transformer = MimeMultipartTransformer(boundary);
    final bodyBytes = await request.body.decode<List<int>>();

    final bodyStream = Stream.fromIterable([bodyBytes]);
    final parts = await transformer.bind(bodyStream).toList();

    final filePart = parts.firstWhere((part)=>part.headers["content-disposition"].contains("filename"));
  
    final fileRegexp = RegExp(r'filename="(.*)"');
    final nameRegexp = RegExp(r'[^A-Za-z0-9\.-]');
    final fn = fileRegexp.firstMatch(filePart.headers['content-disposition']).group(1);
    final fullfn = Translit().toTranslit(source: fn).replaceAll(nameRegexp, '-');
    
    final dotIndex = fullfn.lastIndexOf('.');
    String ext = '';
    if (dotIndex >= 0 ) {
      ext = fullfn.substring(dotIndex);
    }
    final filename = fullfn.substring(0, dotIndex > 0 ? dotIndex : null);
    final content = await filePart.toList();
    final fw = _getFile(filename, ext);
    if (fw != null) {
      final sink = fw.openWrite();
      content.forEach(sink.add);
      await sink.close();
      res['code'] = 0;
      res['status'] = 'Файл успешно загружен';
      res['oldName'] = fn;
      res['newName'] = '/${dir.path}/${path.basename(fw.path)}';
    } else {
      res['status'] = 'Не удалось создать файл';
      res['code'] = -1;
    }
    return Response(200, {}, res);
  } */
}