import 'dart:convert';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/http_singleton.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

Future<List<Emote>> createEmoteObjects(Map<String, dynamic> response) async {
  if (response.containsKey('errors')) {
    throw Exception(response['errors'][0]['message']);
  }

  List<Emote> emoteObjects = [];
  var emotesData = response['data']['emotes'];
  var emoteItems = emotesData['items'];

  for (var emote in emoteItems) {
    var emoteId = emote['id'];
    var emoteName = emote['name'];
    var owner = emote['owner'];
    var ownerUsername = owner != null ? owner['username'] : null;
    var host = emote['host'];
    var hostUrl = host['url'];

    Emote temporaryEmote = Emote(
      id: emoteId,
      name: emoteName,
      ownerUsername: ownerUsername,
      hostUrl: hostUrl,
    );

    Emote loadedEmote = await DatabaseHelper().saveOrGetEmote(temporaryEmote);

    emoteObjects.add(loadedEmote);
  }

  return emoteObjects;
}

//hmm
Future<Emote?> createOneEmoteObject(Map<String, dynamic> response) async {
  if (response.containsKey('errors')) {
    throw Exception(response['errors'][0]['message']);
  }
  var emoteData = response['emote'];

    var emoteId = emoteData['id'];
    var emoteName = emoteData['name'];
    var owner = emoteData['owner'];
    var ownerUsername = owner != null ? owner['username'] : null;
    var host = emoteData['host'];
    var hostUrl = host['url'];

    Emote temporaryEmote = Emote(
      id: emoteId,
      name: emoteName,
      ownerUsername: ownerUsername,
      hostUrl: hostUrl,
    );

    Emote loadedEmote = await DatabaseHelper().saveOrGetEmote(temporaryEmote);

    return loadedEmote;
}



//List is empty when nothing was found
Future<Emote?> requestById(String id) async{
  final HttpLink httpLink = HttpLink(
    "https://7tv.io/v3/gql",
  );

  final GraphQLClient client = GraphQLClient(
    cache: GraphQLCache(store: InMemoryStore()),
    link: httpLink,
  );

  const String query = r'''
    query GetEmote($id: ObjectID!) {
      emote(id: $id) {
        id
        name
        flags
        lifecycle
        tags
        animated
        created_at
        owner_id
        owner {
          id
          username
        }
        host {
          url
        }
        versions {
          id
          name
          description
          created_at
          host {
            url
          }
          lifecycle
          error
          state
          listed
        }
        state
        listed
        personal_use
      }
    }
  ''';

  final QueryOptions options = QueryOptions(
    document: gql(query),
    variables: <String, dynamic>{
      'id': id,
    },
  );

  final QueryResult result = await client.query(options);

  if (result.hasException) {
    print(result.exception.toString());
  }
  var data = result.data;
  if (result.data == null){
    return null;
  }

  return await createOneEmoteObject(data!);
}

//not ideal, doesnt use flutter_graphql
class SevenTv {
  final String endpoint = "https://7tv.io/v3/gql";

  // Future<void> close() async {
  //   client.close();
  // }

  Future<List<Emote>> emoteSearch({
    String searchTerm = "",
    int limit = 30,
    int page = 1,
    bool caseSensitive = false,
    bool animated = false,
    bool exactMatch = false,
    String query = "all",
  }) async {
    var url = Uri.parse(endpoint);
    var queries = {
      "all": 'query SearchEmotes(\$query: String!, \$page: Int, \$sort: Sort, \$limit: Int, \$filter: EmoteSearchFilter) {\n emotes(query: \$query, page: \$page, sort: \$sort, limit: \$limit, filter: \$filter) {\nitems{\n id\n name\n owner{\n username\n }\n host{\n url}}\n}\n}',
      "url": 'query SearchEmotes(\$query: String!, \$page: Int, \$sort: Sort, \$limit: Int, \$filter: EmoteSearchFilter) {\n emotes(query: \$query, page: \$page, sort: \$sort, limit: \$limit, filter: \$filter) {\nitems{host{\n url}}\n}\n}'
    };
    // var headers = {
    //   "Content-Type": "application/json"
    // };
    var payload = {
      "operationName": "SearchEmotes",
      "variables": {
        "query": searchTerm,
        "limit": limit,
        "page": page,
        "sort": {
          "value": "popularity",
          "order": "DESCENDING"
        },
        "filter": {
          "category": "TOP",
          "exact_match": exactMatch,
          "case_sensitive": caseSensitive,
          "ignore_tags": false,
          "zero_width": false,
          "animated": animated,
          "aspect_ratio": ""
        }
      },
      "query": "${queries[query]}"
    };

    var request = await HttpClientSingleton.instance.postUrl(url);
    request.headers.set('Content-Type', 'application/json');
    request.add(utf8.encode(json.encode(payload)));
    var response = await request.close();
    var responseData = await response.transform(utf8.decoder).join();
    var jsonResponse = json.decode(responseData);

    if (jsonResponse.containsKey('errors')) {
      throw Exception(jsonResponse['errors'][0]['message']);
    }
    if (jsonResponse.toString() == "{}"){
      return [];
    }

    return createEmoteObjects(jsonResponse);
  }
}