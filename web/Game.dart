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
  TableElement grid = null;
  Map<String, TableElement> grids = new Map();

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

  TableElement _renderGrid(Element holder, String username, String accountId, bool self) {
    LabelElement name = new LabelElement();
    name.text = username;
    if(self) {

    }
    holder.children.add(name);

    TableElement grid = new TableElement();
    grid.className = 'playergrid';
    holder.children.add(grid);

    grid.createTBody();
    for(int y = 0; y < 4; y++){
      TableRowElement row = grid.insertRow(-1);
      for(int x = 0; x < 4; x++) {
        TableCellElement cell = row.addCell();
        cell.className = 'empty' + (self ? ' opponent' : '');
        if(!self) {
          cell.onClick.listen((e) {
            Map message = {
              'cmd': 'send-all',
              'payload': {
                'alias': this.rtSessionAlias,
                'reliable': true,
                'type': 'string',
                'payload': JSON.encode({
                  'type': 'shot-fired',
                  'pos': {'x': x, 'y': y},
                  'player': accountId
                })
              }
            };
            hydraClient.wsSend(message);
          });
        }
      }
    }

    return grid;
  }

  void _onMatchJoin(JsObject response) {
    if (!response['hasError']) {
      this.match = JSON.decode(context['JSON'].callMethod('stringify', [response['data']]));

      Element playerHolder = querySelector('#playercolumn');
      playerHolder.children.clear();

      LabelElement name = new LabelElement();
      name.text = match['id'];
      playerHolder.children.add(name);
      playerHolder.children.add(new BRElement());

      this.grid = _renderGrid(playerHolder, player.username, player.account['id'], true);
      this.grid.className = 'playergrid online';

      Element opponentHolder = querySelector('#opponentcolumn');
      opponentHolder.children.clear();
      this.grids.clear();

      List<String> currentPlayers = this.match['players']['current'];
      List allPlayers = this.match['players']['all'];
      for(String playerId in currentPlayers) {
        if(playerId != this.player.account['id']) {
          for(Map player in allPlayers) {
            if(player['account_id'] == playerId) {
              this.grids[playerId] = _renderGrid(querySelector('#opponentcolumn'), player['identity']['username'], player['account_id'], false);
              this.grids[playerId].className = 'playergrid offline';
              break;
            }
          }
        }
      }

      Map message = {
        'cmd': 'join',
        'payload': {
          'type': 'match',
          'session': this.match['id']
        }
      };
      hydraClient.wsSend(message);
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

      hydraClient.put('matches/matchmaking/5-way/join', {}, (JsObject response) {
        this._onMatchJoin(response);
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
          if(player['id'] != this.player.account['id'] && this.grids[player['id']] != null)
            this.grids[player['id']].className = 'playergrid online';
        }
      }
    } else if(cmd == 'player-joined') {
      if(payload['alias'] == this.rtSessionAlias) {
        this.grids[payload['player']] = _renderGrid(querySelector('#opponentcolumn'), payload['data']['identity']['username'], payload['player'],false);
      }
    } else if(cmd == 'send-simulation') {
      if(payload['alias'] == this.rtSessionAlias) {
        print(payload);
      }
    } else if(cmd == 'send') {
      if(payload['alias'] == this.rtSessionAlias) {
        Map data = JSON.decode(payload['payload']);
        if(data['type'] == 'shot-fired') {
          String playerId = data['player'];
          Map pos = data['pos'];
          int x = pos['x'];
          int y = pos['y'];
          if(playerId == this.player.account['id']) {
            this.grid.rows[y].cells[x].className = 'hit';
          } else if(this.grids[playerId] != null) {
            this.grids[playerId].rows[y].cells[x].className = 'hit';
          }
        }
      }
    }
  }

  void _getMatches() {
    hydraClient.put('matches/matchmaking/5-way', {}, (JsObject response) {
      if (!response['hasError']) {
        List matches = JSON.decode(context['JSON'].callMethod('stringify', [response['data']]));
        TableElement matchListHolder = querySelector('#matchlist');
        matchListHolder.createTBody();
        for(Map existingMatch in matches) {
          TableRowElement row = matchListHolder.insertRow(-1);
          TableCellElement name = row.addCell();
          name.text = existingMatch['id'];
          name.className = 'clickable';
          name.onClick.listen((e) {
            hydraClient.put('matches/matchmaking/5-way/join/${existingMatch['id']}', {}, (JsObject response) {
              this._onMatchJoin(response);
            });
          });

          List currentPlayers = existingMatch['players']['current'];
          TableCellElement players = row.addCell();
          players.text = '${currentPlayers.length}';

          TableCellElement created = row.addCell();
          created.text = existingMatch['created_at'];
        }
      }
    });
  }

  void hydraLogin(var auth, HydraCallback callback) {
    hydraClient.startupWithOptions(auth, ['profile', 'account', 'configuration'], (JsObject response){
      if (!response['hasError']) {
        isAuthenticated = true;
        saveAuthToken(hydraClient['authToken']);

        this.player = new FiveBomberPlayer(response['data']);
        this.hydraClient.onRtMessage = this._onRtMessage;

        this._getMatches();
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
