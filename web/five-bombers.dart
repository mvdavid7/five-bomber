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
  client.init(Uri.base.queryParameters['hydra_url'], Uri.base.queryParameters['hydra_apikey']);

  Game game = new Game(client);

  window.onBeforeUnload.listen((BeforeUnloadEvent e) {
    if(game.match != null)
      e.returnValue = "You are in a match. If you quit, you will forfeit.";
  });

  context['randomMatch'] = () {
    game.findMatch((JsObject) {

    });
  };

  context['listMatches'] = () {
    game.listMatches((JsObject) {

    });
  };

  context['externalAuth'] = (auth) {
    game.externalAuth(auth, (JsObject) {

    });
  };

  context['onReady'] = () {
    game.onReady();
  };
}
