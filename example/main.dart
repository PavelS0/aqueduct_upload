import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:aqueduct_upload/upload_aqueduct.dart';

///
/// Entry point for app
///
Future main() async {
  final app = Application<AppChannel>();
  await app.start(numberOfInstances: 1);

  print("Application started on port: ${app.options.port}.");
  print("Use Ctrl-C (SIGINT) to stop running the application.");
}

class AppChannel extends ApplicationChannel {
  @override
  Controller get entryPoint {
    final router = new Router();

    router.route('/').linkFunction((Request req) => Response.ok('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Отправка файла на сервер</title>
        </head>
        <body>
          <form action="/upload" enctype="multipart/form-data" method="post">
          <p><input type="file" name="f">
          <input type="hidden" name="name" value="save">
          <input type="submit" value="Отправить"></p>
          </form> 
        </body>
        </html>
      ''')..contentType = ContentType.html);

    router.route('/upload').link(() => UploadController(Directory('upload')));

    return router;
  }
}
