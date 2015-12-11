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
  String url = 'https://api.hydra.agoragames.com';
  String apiKey = '4191b07670094fa588d70d801d2b7805';
  if(Uri.base.queryParameters.containsKey('hydra_url'))
    url = Uri.base.queryParameters['hydra_url'];
  if(Uri.base.queryParameters.containsKey('hydra_apikey'))
    apiKey = Uri.base.queryParameters['hydra_apikey'];
  client.init(url, apiKey);

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
