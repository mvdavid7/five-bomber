library hydra;

import 'dart:html';
import 'dart:js';
import 'dart:async';

typedef void HydraCallback(JsObject response);

class Hydra {
  var _client = null;
  WebSocket ws = null;

  Hydra(var client) {
    _client = client;
  }

  operator [](attr) => _client[attr];

  void init(String url, String apiKey) {
    _client.callMethod('init', [url, apiKey]);
  }

  void startupWithOptions(var auth, List options, HydraCallback callback) {
    JsObject jsAuth = auth is Map ? new JsObject.jsify(auth) : auth;
    JsObject jsOptions = new JsObject.jsify(options);
    JsFunction jsCallback = _getJSCallback((JsObject response) {
      if(!response['hasError']) {
        if(response['data']['configuration'] != null) {
          JsObject realtime = response['data']['configuration']['realtime'];
          String cluster = realtime['default-cluster'];
          JsObject server = realtime['servers'][cluster]['ny2-do-prod-realtime-4/1'];
          String wsAddress = server['ws'];
          _realtimeConnect(wsAddress);
        } else {
          print('Not connecting to realtime: missing configuration');
        }
      }
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

  void _realtimeConnect(String wsAddress) {
    var reconnectScheduled = false;
    ws = new WebSocket(wsAddress);

    void scheduleReconnect() {
      if (!reconnectScheduled) {
        new Timer(new Duration(milliseconds: 1000), () => _realtimeConnect(wsAddress));
      }
      reconnectScheduled = true;
    }

    ws.onOpen.listen((e) {
      print('Realtime: Connected');
      ws.send('Hello from Dart!');
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
      print('Realtime: Received message: ${e.data}');
    });
  }
}
