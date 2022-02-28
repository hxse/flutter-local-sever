// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import "package:velocity_x/velocity_x.dart";

import 'tray.dart';
import "local_server.dart";
import 'forward proxy.dart';

part 'main.g.dart';

@hwidget
Widget myCounter(String title) {
  final counter = useState(0);
  final testText = useState('hhh');
  void _incrementCounter() {
    print([counter.value, 'in']);
    counter.value = counter.value >= 3 ? counter.value : counter.value + 1;
    // counter.value++;
  }

  useMemoized(myHttp(testText, counter), []);
  useMemoized(() async => await forwardProxy(), []);

  useEffect(() {
    // print('i am effect');
  });

  print([counter.value, 'out']);

  return Scaffold(
    appBar: AppBar(
      title: Text(title),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            counter.value.toString(),
          ),
          Text(testText.value.toString())
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _incrementCounter,
      tooltip: 'Increment',
      child: const Icon(Icons.add),
    ), // This trailing comma makes auto-formatting nicer for build methods.
  );
}

@swidget
Widget myApp() {
  print('hello world');
  return MaterialApp(
    title: 'Flutter Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: const MyCounter('hello'),
  );
}

void main() {
  // myHttp();
  runApp(const MyApp()
      // const Example(0,'hello world'),
      // Foo(),
      );
  initWindows();
  initSystemTray();
}
