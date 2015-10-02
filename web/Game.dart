// Copyright (c) 2014, David Andrade

library game;

import 'dart:html';
import 'dart:js';
import 'dart:convert';
import 'Hydra.dart';
import 'Player.dart';


class Game {
  Hydra hydraClient;
  FiveBomberPlayer player = null;
  Map match = null;
  int rtSessionAlias;

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

  void _renderGrid(Element holder, String username, bool allowUsernameChange) {
    LabelElement name = new LabelElement();
    name.text = username;
    if(allowUsernameChange) {

    }
    holder.children.add(name);

    TableElement grid = new TableElement();
    grid.className = 'playergrid';
    holder.children.add(grid);

    grid.createTBody();
    for(int y = 0; y < 4; y++){
      TableRowElement row = grid.insertRow(-1);
      for(int x = 0; x < 4; x++){
        TableCellElement cell = row.insertCell(0);
        cell.className = 'empty';
      }
    }
  }

  void findMatch(HydraCallback callback) {
    if(isAuthenticated) {
      if(match != null) {
        Map message = {
          'cmd': 'leave',
          'payload': {
            'session': this.rtSessionAlias
          }
        };
        hydraClient.wsSend(message);
        this.match = null;
      }

      Element playerHolder = querySelector('#playercolumn');
      playerHolder.children.clear();
      _renderGrid(playerHolder, player.username, true);

      Element opponentHolder = querySelector('#opponentcolumn');
      opponentHolder.children.clear();

      hydraClient.put('matches/matchmaking/5-way/join', {}, (JsObject response) {
        if (!response['hasError']) {
          this.match = JSON.decode(context['JSON'].callMethod('stringify', [response['data']]));
          Map message = {
            'cmd': 'join',
            'payload': {
              'type': 'match',
              'session': this.match['id']
            }
          };
          hydraClient.wsSend(message);
        }

        callback(response);
      });
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

  void _onRtMessage(String cmd, Map payload) {
    print(payload);
    if(cmd == 'join') {
      if(payload['success']) {
        this.rtSessionAlias = payload['sessionAlias'];
        List players = payload['data']['players'];
        for(Map player in players) {
          if(player['id'] != this.player.account['id'])
            _renderGrid(querySelector('#opponentcolumn'), player['identity']['username'], false);
        }
      }
    } else if(cmd == 'player-joined') {
      _renderGrid(querySelector('#opponentcolumn'), payload['data']['identity']['username'], false);
    } else if(cmd == 'send-simulation') {
      if(payload['alias'] == this.rtSessionAlias) {
        print(payload);
      }
    }
  }

  void hydraLogin(var auth, HydraCallback callback) {
    hydraClient.startupWithOptions(auth, ['profile', 'account', 'configuration'], (JsObject response){
      if (!response['hasError']) {
        isAuthenticated = true;
        saveAuthToken(hydraClient['authToken']);

        this.player = new FiveBomberPlayer(response['data']);
        this.hydraClient.onRtMessage = this._onRtMessage;
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
