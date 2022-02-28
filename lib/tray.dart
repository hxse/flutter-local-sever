// ignore_for_file: avoid_print

import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';


bool state = true;

switchWindows(windows) {
  if (state == true) {
    windows.show();
  } else {
    windows.hide();
  }
  state = !state;
}

initWindows() {
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(600, 450);
    win.minSize = initialSize;
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "How to use system tray with Flutter";
    switchWindows(win);
  });
}

Future<void> initSystemTray() async {
  final AppWindow _appWindow = AppWindow();
  print('托盘');
  final tray = SystemTray();
  const icon = 'assets/Icons8-Halloween-Cat.ico';
  await tray.initSystemTray(
    title: 'Hello',
    iconPath: icon,
    toolTip: "How to use system tray with Flutter",
  );
  final items = [
    MenuItem(label: 'show', onClicked: _appWindow.show),
    MenuItem(label: 'hide', onClicked: _appWindow.hide),
    MenuItem(label: 'exit', onClicked: _appWindow.close)
  ];
  await tray.setContextMenu(items);

  // handle system tray event
  tray.registerSystemTrayEventHandler((eventName) {
    print("eventName: $eventName");
    if (eventName == "leftMouseDown") {
    } else if (eventName == "leftMouseUp") {
      switchWindows(_appWindow);
    } else if (eventName == "rightMouseDown") {
    } else if (eventName == "rightMouseUp") {
      tray.popUpContextMenu();
    }
  });
}
