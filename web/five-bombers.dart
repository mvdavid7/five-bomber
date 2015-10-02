// Copyright (c) 2014, David Andrade

import 'dart:html';
import 'dart:js';
import 'Hydra.dart';
import 'Game.dart';

String getJsObjectString(var jsObj) {
  var JSON = context['JSON'];
  return JSON.callMethod('stringify', [jsObj]);
}

void printJsObject(var jsObj) {
  print(getJsObjectString(jsObj));
}

void main() {
  Hydra client = new Hydra(new JsObject(context['Client']));
  client.init('https://api.hydra.agoragames.com', '1d30b465276743b99647809499a5374d');

  Game game = new Game(client);

  window.onBeforeUnload.listen((BeforeUnloadEvent e) {
    if(game.match != null)
      e.returnValue = "You are in a match. If you quit, you will forfeit.";
  });

  context['findMatch'] = () {
    game.findMatch((JsObject) {

    });
  };

  context['externalAuth'] = (auth) {
    game.externalAuth(auth, (JsObject) {

    });
  };
}
