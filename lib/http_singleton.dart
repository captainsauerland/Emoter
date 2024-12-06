import 'dart:io';

class HttpClientSingleton {

  // The single instance of this class
  static final HttpClientSingleton instance = HttpClientSingleton._();

  // The HTTP client
  final HttpClient _client;

  HttpClientSingleton._() : _client = HttpClient() {
    _client.userAgent = 'Chrome/131.0.6778.33';
  }

  //Example method to make a GET request
  Future<HttpClientRequest> get(Uri url) async {
    return await _client.getUrl(url);
  }

  // Updated method to make a POST request with Uri
  Future<HttpClientRequest> postUrl(Uri url) async {
    return await _client.postUrl(url);
  }
}