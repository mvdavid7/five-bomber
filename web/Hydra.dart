library hydra;

import 'dart:html';
import 'dart:js';
import 'dart:async';
import 'dart:convert';

typedef void HydraCallback(JsObject response);
typedef void RtMessageCallback(String, Map);

class Hydra {
  var _client = null;
  WebSocket ws = null;
  String _realtimeConnectionId = null;
  RtMessageCallback onRtMessage = null;
  String rtCluster = null;
  String apiKey = null;

  Hydra(var client) {
    _client = client;
  }

  operator [](attr) => _client[attr];

  void init(String url, String apiKey) {
    this.apiKey = apiKey;
    _client.callMethod('init', [url, apiKey]);
  }

  void startupWithOptions(var auth, List options, HydraCallback callback) {
    JsObject jsAuth = auth is Map ? new JsObject.jsify(auth) : auth;
    JsObject jsOptions = new JsObject.jsify(options);
    JsFunction jsCallback = _getJSCallback((JsObject response) {
      if(!response['hasError']) {
        if(response['data']['configuration'] != null) {
          JsObject account = response['data']['account'];
          Map realtime = JSON.decode(context['JSON'].callMethod('stringify', [response['data']['configuration']['realtime']]));
          Map clusters = realtime['servers'];
          this.rtCluster = clusters.keys.first;
          Map servers = clusters[clusters.keys.first];
          Map server = servers[servers.keys.first];
          _realtimeConnect(server['ws'], account['id']);
        } else {
          print('Not connecting to realtime: missing configuration');
        }
      }
      callback(response);
    });
    _client.callMethod('startupWithOptions', [jsAuth, jsOptions, jsCallback]);
  }

  void get(String endpoint, HydraCallback callback) {
    _request(endpoint, 'GET', null, callback);
  }

  void post(String endpoint, var data, HydraCallback callback) {
    _request(endpoint, 'POST', data, callback);
  }

  void put(String endpoint, var data, HydraCallback callback) {
    _request(endpoint, 'PUT', data, callback);
  }

  void delete(String endpoint, HydraCallback callback) {
    _request(endpoint, 'DELETE', null, callback);
  }

  void _request(String endpoint, String method, var data, HydraCallback callback) {
    JsObject jsData = null;
    if (data != null) {
      jsData = (data is Map || data is Iterable) ? new JsObject.jsify(data) : data;
    }

    JsFunction jsCallback = _getJSCallback(callback);
    _client.callMethod('request', [endpoint, method, jsData, jsCallback]);
  }

  JsFunction _getJSCallback(HydraCallback callback) {
    return new JsFunction.withThis((var client, JsObject response) {
      callback(response);
    });
  }

  void _realtimeConnect(String wsAddress, String accountId) {
    var reconnectScheduled = false;
    ws = new WebSocket(wsAddress);

    void scheduleReconnect() {
      if (!reconnectScheduled) {
        new Timer(new Duration(milliseconds: 1000), () => _realtimeConnect(wsAddress, accountId));
      }
      reconnectScheduled = true;
    }

    ws.onOpen.listen((e) {
      print('Realtime: Connected');
      Map authMessage = {
        'apiKey': _client['apiKey'],
        'accessToken': _client['accessToken'],
        'accountId': accountId,
        'data': {
          'connection': _realtimeConnectionId
        }
      };
      Map message = {
        'cmd': 'auth',
        'payload': authMessage
      };
      wsSend(message);
    });

    ws.onClose.listen((e) {
      print('Realtime: Websocket closed, retrying in 1 second');
      scheduleReconnect();
    });

    ws.onError.listen((e) {
      print("Realtime: Error connecting to ws");
      scheduleReconnect();
    });

    ws.onMessage.listen((MessageEvent e) {
      Map message = JSON.decode(e.data);
      String cmd = message['cmd'];
      print('Realtime: Received message: ${cmd}');

      if(cmd == 'auth') {
        if(message['payload']['success']) {
          _realtimeConnectionId = message['payload']['connectionId'];
          _wsPing();
        }
      } else {
        if(this.onRtMessage != null) {
          this.onRtMessage(cmd, message['payload']);
        }
      }
    });
  }

  void wsSend(Map message) {
    var msgString = JSON.encode(message);
    print(msgString);
    ws.send(msgString);
  }

  void _wsPing() {
    Map message = {
      'cmd': 'ping',
      'payload': {}
    };
    wsSend(message);
    new Timer(new Duration(milliseconds: 15000), () => this._wsPing());
  }
}
