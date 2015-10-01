var Client = function() {
}

Client.prototype = {

version: '0.1.0',
HEADER_APIKEY: "x-hydra-api-key",
HEADER_ACCESS_TOKEN: "x-hydra-access-token",
HEADER_CONTENT_TYPE: "content-type",
HEADER_SDK_USER_AGENT: "x-hydra-user-agent",
SDK_USER_AGENT: "Hydra-JS/" + this.version,

init: function(url, apiKey) {
    this.url = url;
    this.apiKey = apiKey;

    console.log('Connecting to: ' + url)
},

startup: function(auth, callback) {
    this.startupWithOptions(auth, null, callback);
},

startupWithOptions: function(auth, options, callback) {
    this.options = options;
    this.initCallback = callback;

    if (typeof auth == 'object' || auth instanceof Object) {
        this.authenticate(auth);
    } else if (typeof auth == 'string' || auth instanceof String) {
        this.authToken = auth;
        this.access(this.authToken);
    }
},

authenticate: function(auth) {
    this.request('auth', 'POST', auth, this.handleAuthResponse.bind(this))
},

handleAuthResponse: function(response) {
    if (!response.hasError) {
        this.authToken = response.data['token'];
        this.access(this.authToken);
    } else {
        this.loadCompleted(response);
    }
},

access: function(authToken) {
    var data = {'auth_token': authToken}
    if (this.options != null) {
        data['options'] = this.options;
    }

    this.request('access', 'POST', data, this.handleAccessResponse.bind(this))
},

handleAccessResponse: function(response) {
    if (!response.hasError) {
        this.accessToken = response.data['token'];

        this.loadCompleted(response);
    } else {
        this.loadCompleted(response);
    }
},

loadCompleted: function(response) {
    if (response.hasError) {
        console.error('Client startup failed');
    } else {
        console.log('Client startup successful!')
    }
    this.initCallback(response);
},

request: function(endpoint, verb, data, callback) {
    console.debug('Requesting: ' + endpoint);

    xmlHttp = new XMLHttpRequest();
    xmlHttp.onreadystatechange = this.getRequestHandler(xmlHttp, callback);
    xmlHttp.open(verb, this.url + "/" + endpoint, true);

    xmlHttp.setRequestHeader(this.HEADER_APIKEY, this.apiKey);
    xmlHttp.setRequestHeader(this.HEADER_CONTENT_TYPE, 'application/json');
    xmlHttp.setRequestHeader(this.HEADER_SDK_USER_AGENT, this.SDK_USER_AGENT);

    if (this.accessToken) {
        xmlHttp.setRequestHeader(this.HEADER_ACCESS_TOKEN, this.accessToken);
    }

    xmlHttp.send(JSON.stringify(data));
},

getRequestHandler: function(xmlHttp, callback) {
    return function() {
        if (xmlHttp.readyState == 4) {
            console.debug('HTTP Status: ' + xmlHttp.status)

            var response = new Object();
            response.status = xmlHttp.status;
            response.hasError = xmlHttp.status != 200 && xmlHttp.status != 201;
            if (xmlHttp.response) {
                response.data = JSON.parse(xmlHttp.response);
            }

            callback(response)
        }
    }
},

}