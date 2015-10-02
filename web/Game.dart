// Copyright (c) 2014, David Andrade

library game;

import 'dart:html';
import 'dart:js';
import 'Hydra.dart';
import 'Player.dart';


class Game {
  Hydra hydraClient;
  FiveBomberPlayer player = null;
  JsObject match = null;

  Game(Hydra client) {
    this.hydraClient = client;

    String authToken = getSavedAuthToken();
    if(authToken != null) {
      hydraLogin(authToken, (JsObject response) {
        if (response['hasError']) {
          print('Invalid saved token, will have to create new account');
        }
      });
    }
  }

  void findMatch(HydraCallback callback) {
    if(isAuthenticated) {

    } else {
      hydraLogin({'anonymous': true}, (JsObject response) {
        if (!response['hasError']) {
          findMatch(callback);
        } else {
          callback(response);
        }
      });
    }
  }

  void setUsername(String username, HydraCallback callback) {
    hydraClient.put('accounts/me/identity', {'username': username}, (JsObject response) {
      if (!response['hasError']) {
        player.username = username;
      }

      callback(response);
    });
  }

  void externalAuth(JsObject auth, HydraCallback callback) {
    if(isAuthenticated) {
      hydraClient.put('accounts/me/link', auth, callback);
    } else {
      hydraLogin(auth, callback);
    }
  }

  // Hydra functions

  bool isAuthenticated = false;

  void hydraLogin(var auth, HydraCallback callback) {
    hydraClient.startupWithOptions(auth, ['profile', 'account'], (JsObject response){
      if (!response['hasError']) {
        isAuthenticated = true;
        saveAuthToken(hydraClient['authToken']);

        this.player = new FiveBomberPlayer(response['data']);
      }

      callback(response);
    });
  }

  String getSavedAuthToken() {
    String cookieName = 'five-bombers-auth-token=';
    List<String> ca = document.cookie.split(';');
    for (int i = 0; i < ca.length; i++) {
      String c = ca[i];
      c = c.trim();
      if (c.indexOf(cookieName) == 0) {
        return c.substring(cookieName.length);
      }
    }
    return null;
  }

  void saveAuthToken(String authToken) {
    DateTime today = new DateTime.now();
    DateTime expires = today.add(new Duration(days: 60));
    document.cookie = 'five-bombers-auth-token=' + authToken + '; path=/; expires=' + expires.toString();
  }
}
