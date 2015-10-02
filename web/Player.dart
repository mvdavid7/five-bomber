library player;

import 'dart:js';

class FiveBomberPlayer {
  String username = null;
  JsObject account = null;
  JsObject profile = null;

  FiveBomberPlayer(JsObject loginData) {
    account = loginData['account'];
    profile = loginData['profile'];

    username = account['identity']['username'];
  }
}