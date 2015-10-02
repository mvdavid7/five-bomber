library player;

import 'dart:js';

class FiveBomberPlayer {
  String username = null;
  JsObject _account = null;
  JsObject _profile = null;

  FiveBomberPlayer(JsObject loginData) {
    _account = loginData['account'];
    _profile = loginData['profile'];

    username = _account['identity']['username'];
  }
}