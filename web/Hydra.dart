library hydra;

import 'dart:js';

typedef void HydraCallback(JsObject response);

class Hydra {
  var _client = null;

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
    JsFunction jsCallback = _getJSCallback(callback);
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
}
