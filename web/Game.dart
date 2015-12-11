// Copyright (c) 2014, David Andrade

library game;

import 'dart:async';
import 'dart:html';
import 'dart:js';
import 'dart:convert';
import 'Hydra.dart';
import 'Player.dart';

enum State { Setup, Ready, Waiting, Turn, Finished}
enum SpotState { Blank, Piece, Hit }

class Game {
  Hydra hydraClient;
  FiveBomberPlayer player = null;
  Map match = null;
  int rtSessionAlias;
  TableElement grid = null;
  Map<String, TableElement> grids = new Map();
  State state = State.Setup;
  int timerSeconds;

  List<List<SpotState>> myGrid = new List();
  int piecesLeft = 4;

  Game(Hydra client) {
    this.hydraClient = client;
    for(int i = 0; i < 4; i++) {
      List<SpotState> row = new List();
      for(int j = 0; j < 4; j++) {
        row.add(SpotState.Blank);
      }
      this.myGrid.add(row);
    }

    String authToken = getSavedAuthToken();
    if(authToken != null) {
      hydraLogin(authToken, (JsObject response) {
        if (response['hasError']) {
          print('Invalid saved token, will have to create new account');
        }
      });
    }
  }

  void _updateTimer() {
    querySelector('#timer').text = '${this.timerSeconds}';
  }

  void _startTimer(int seconds) {
    this.timerSeconds = seconds;
    this._updateTimer();

    new Timer.periodic(
        new Duration(seconds: 1),
        (Timer timer) {
          this.timerSeconds--;
          this._updateTimer();
          if(this.timerSeconds <= 0)
            timer.cancel();
        });
  }

  void _setState(State state) {
    String instr;
    this.state = state;
    switch(state) {
      case State.Setup:
        instr = 'Set up';
        break;
      case State.Ready:
        instr = 'Wait';
        break;
      case State.Waiting:
        instr = 'Wait';
        break;
      case State.Turn:
        instr = 'FIRE';
        break;
      case State.Finished:
        instr = 'Done';
        break;
    }

    if(state == State.Setup)
      querySelector('#self .playergrid').classes.add('setup');
    else
      querySelector('#self .playergrid').classes.remove('setup');

    querySelector('#instructions').text = instr;
  }

  void _setSpotState(int x, int y, SpotState state) {
    String cls;
    this.myGrid[y][x] = state;
    switch(state) {
      case SpotState.Blank:
        cls = 'empty';
        break;
      case SpotState.Piece:
        cls = 'piece';
        break;
      case SpotState.Hit:
        cls = 'hit';
        break;
    }
    this.grid.rows[y].cells[x].className = cls;
  }

  SpotState _getSpotState(int x, int y) {
    return this.myGrid[y][x];
  }

  void onSetup() {
    this._setState(State.Setup);
    this._startTimer(20);
  }

  void onReady() {
    querySelector('#action').style.display = 'none';
    this._setState(State.Ready);
    this._sendAllGameMessage({
      'type': 'ready'
    });
  }

  TableElement _renderGrid(Element holder, String username, String accountId, bool self) {
    LabelElement name = new LabelElement();
    name.text = username;
    if(self) {

    }
    holder.children.add(name);

    TableElement grid = new TableElement();
    grid.classes.add('playergrid');
    holder.children.add(grid);

    grid.createTBody();
    for(int y = 0; y < 4; y++){
      TableRowElement row = grid.insertRow(-1);
      for(int x = 0; x < 4; x++) {
        TableCellElement cell = row.addCell();
        cell.className = 'empty';
        cell.onClick.listen((e) {
          if(!self) {
            this._sendAllGameMessage({
              'type': 'shot-fired',
              'pos': {'x': x, 'y': y},
              'player': accountId
            });
          } else if(this.state == State.Setup) {
            if(_getSpotState(x, y) == SpotState.Blank) {
              if(this.piecesLeft > 0) {
                this._setSpotState(x, y, SpotState.Piece);
                this.piecesLeft--;
              }
            }
            else if(_getSpotState(x, y) == SpotState.Piece) {
              this._setSpotState(x, y, SpotState.Blank);
              this.piecesLeft++;
            }
          }
        });
      }
    }

    return grid;
  }

  void _onMatchJoin(JsObject response) {
    if (!response['hasError']) {
      querySelector('#controls').style.display = 'inherit';
      this.match = JSON.decode(context['JSON'].callMethod('stringify', [response['data']]));

      Element playerHolder = querySelector('#self');
      playerHolder.children.clear();

      LabelElement name = new LabelElement();
      name.text = match['id'];

      this.grid = _renderGrid(playerHolder, player.username, player.account['id'], true);
      this.grid.className = 'playergrid online';

      this.grids.clear();

      List<String> currentPlayers = this.match['players']['current'];
      List allPlayers = this.match['players']['all'];
      for(String playerId in currentPlayers) {
        if(playerId != this.player.account['id']) {
          for(Map player in allPlayers) {
            if(player['account_id'] == playerId) {
              Element opponentHolder = querySelector('#opponent${this.grids.length + 1}');
              opponentHolder.classes.remove('empty');
              opponentHolder.classes.add('taken');
              this.grids[playerId] = _renderGrid(opponentHolder, player['identity']['username'], player['account_id'], false);
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

      this.onSetup();
    }
  }

  void findMatch(HydraCallback callback) {
    if(isAuthenticated) {
      leaveMatch((JsObject response) {
        // Ignore this for now, we tried our best
      });

      hydraClient.put('matches/matchmaking/5-way/join', {'cluster': this.hydraClient.rtCluster}, (JsObject response) {
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

  void _sendAllGameMessage(Map payload) {
    Map message = {
      'cmd': 'send-all',
      'payload': {
        'alias': this.rtSessionAlias,
        'reliable': true,
        'type': 'string',
        'payload': JSON.encode(payload)
      }
    };
    hydraClient.wsSend(message);
  }

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
        String player = payload['player'];
        if(this.grids.containsKey(player)) {
          this.grids[player].className = 'playergrid online';
        } else {
          Element opponentHolder = querySelector('#opponent${this.grids.length + 1}');
          this.grids[payload['player']] = _renderGrid(opponentHolder, payload['data']['identity']['username'], payload['player'], false);
        }
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
            if(this._getSpotState(x, y) == SpotState.Piece) {
              this._setSpotState(x, y, SpotState.Hit);
            }
          } else if(this.grids[playerId] != null) {
            this.grids[playerId].rows[y].cells[x].className = 'hit';
          }
        }
      }
    }
  }

  void _listMatches(HydraCallback callback) {
    hydraClient.put('matches/matchmaking/5-way', {'cluster': this.hydraClient.rtCluster}, (JsObject response) {
      if (!response['hasError']) {
        List matches = JSON.decode(context['JSON'].callMethod('stringify', [response['data']]));
        TableElement matchListHolder = querySelector('#matchlist');
        matchListHolder.children.clear();
        matchListHolder.createTBody();
        for(Map existingMatch in matches) {
          TableRowElement row = matchListHolder.insertRow(-1);
          TableCellElement name = row.addCell();
          name.text = existingMatch['id'];
          name.className = 'clickable';
          name.onClick.listen((e) {
            hydraClient.put('matches/matchmaking/5-way/join/${existingMatch['id']}', {'cluster': this.hydraClient.rtCluster}, (JsObject response) {
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

      callback(response);
    });
  }

  void listMatches(HydraCallback callback) {
    if(isAuthenticated) {
      _listMatches(callback);
    } else {
      hydraLogin({'anonymous': true}, (JsObject response) {
        if (!response['hasError']) {
          listMatches(callback);
        } else {
          callback(response);
        }
      });
    }
  }

  void leaveMatch(HydraCallback callback) {
    if(match != null) {
      Map message = {
        'cmd': 'leave',
        'payload': {
          'session': this.rtSessionAlias
        }
      };
      hydraClient.wsSend(message);

      hydraClient.put('matches/${match['id']}/leave', {}, callback);
      this.match = null;
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
