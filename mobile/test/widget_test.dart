import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nidal_games/api.dart';
import 'package:nidal_games/main.dart';

void main(){
 test('Unconfigured API fails clearly',()async{final api=Api('');expect(()=>api.request('games/'),throwsException);});
 test('API fetch decodes JSON',()async{final api=Api('https://example.test',client:MockClient((r)async=>http.Response('{"count":2}',200)));expect((await api.request('games/'))['count'],2);});
 test('Writes fetch CSRF and send cookie',()async{int calls=0;final api=Api('https://example.test',client:MockClient((r)async{calls++;if(r.url.path.endsWith('csrf/'))return http.Response('{"csrfToken":"abc"}',200,headers:{'set-cookie':'csrftoken=abc; Path=/'});expect(r.headers['X-CSRFToken'],'abc');expect(r.headers['Cookie'],'csrftoken=abc');expect(jsonDecode(r.body)['name'],'Weekend');return http.Response('{"id":1}',201);}));expect((await api.request('collections/','POST',{'name':'Weekend'}))['id'],1);expect(calls,2);});
 test('Server failures are not treated as success',()async{final api=Api('https://example.test',client:MockClient((r)async=>http.Response('{"detail":"Forbidden"}',403)));expect(()=>api.request('stats/'),throwsException);});
 testWidgets('Nidal app opens in Arabic browse mode',(tester)async{SharedPreferences.setMockInitialValues({});await tester.pumpWidget(const NidalApp());await tester.pump();expect(find.text('NIDAL GAMES'),findsOneWidget);await tester.pump(const Duration(seconds:1));expect(tester.takeException(),isNull);});
}
