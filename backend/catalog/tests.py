from django.test import TestCase,override_settings
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from .models import Game,Category,Collection,Favorite,Review
from unittest.mock import patch
class CatalogTests(TestCase):
 def setUp(self):
  self.client=APIClient();self.u=User.objects.create_user('player',password='LongSpacePass42!');self.other=User.objects.create_user('other',password='OtherSpacePass42!')
  self.cat=Category.objects.create(name='Strategy',name_ar='استراتيجية',slug='strategy')
  self.game=Game.objects.create(title='Official Game',slug='official-game',description='Strategy world',description_ar='عالم استراتيجي',official_url='https://play0ad.com/',is_free=True,platforms=['windows'])
  self.game.categories.add(self.cat)
 def auth(self):self.client.force_authenticate(self.u)
 def test_catalog_public(self):self.assertEqual(self.client.get('/api/games/').data['count'],1)
 def test_search_matches(self):self.assertEqual(self.client.get('/api/games/?search=Official').data['count'],1)
 def test_search_arabic(self):self.assertEqual(self.client.get('/api/games/?search=عالم').data['count'],1)
 def test_search_empty(self):self.assertEqual(self.client.get('/api/games/?search=missing').data['count'],0)
 def test_category_filter(self):self.assertEqual(self.client.get('/api/games/?category=strategy').data['count'],1)
 def test_free_filter(self):self.assertEqual(self.client.get('/api/games/?free=1').data['count'],1)
 def test_discount_no_invented_data(self):self.assertEqual(self.client.get('/api/games/?discount=1').data['count'],0)
 def test_hidden_games(self):self.game.published=False;self.game.save();self.assertEqual(self.client.get('/api/games/').data['count'],0)
 def test_library_requires_login(self):self.assertIn(self.client.get('/api/library/').status_code,[401,403])
 def test_favorite_idempotent(self):
  self.auth()
  for _ in range(2):self.assertEqual(self.client.post('/api/games/official-game/favorite/').status_code,200)
  self.assertEqual(Favorite.objects.count(),1)
  self.assertEqual(len(self.client.get('/api/library/').data['favorites']),1)
  self.assertEqual(self.client.delete('/api/games/official-game/favorite/').status_code,204)
 def test_collection_isolation(self):
  c=Collection.objects.create(user=self.other,name='Private');self.auth();self.assertEqual(self.client.get('/api/collections/'+str(c.id)+'/').status_code,404)
 def test_collection_crud(self):
  self.auth();r=self.client.post('/api/collections/',{'name':'Weekend','games':[self.game.id]});self.assertEqual(r.status_code,201);self.assertEqual(self.client.delete('/api/collections/'+str(r.data['id'])+'/').status_code,204)
 def test_review_validation(self):self.auth();self.assertEqual(self.client.post('/api/games/official-game/reviews/',{'rating':6}).status_code,400)
 def test_review_upsert(self):
  self.auth()
  for n in [3,5]:self.assertEqual(self.client.post('/api/games/official-game/reviews/',{'rating':n,'text':'Good'}).status_code,201)
  self.assertEqual(Review.objects.count(),1);self.assertEqual(self.client.get('/api/games/official-game/').data['rating'],5)
 def test_official_source_no_fake_progress(self):
  self.auth();r=self.client.post('/api/games/official-game/open_source/');self.assertEqual(r.data['url'],'https://play0ad.com/');self.assertFalse(r.data['progress_supported'])
 def test_download_manual_complete(self):
  self.auth();self.client.post('/api/games/official-game/open_source/');d=self.client.get('/api/downloads/').data['results'][0];self.assertEqual(self.client.post('/api/downloads/'+str(d['id'])+'/complete/').status_code,200)
 def test_stats_staff_only(self):self.auth();self.assertEqual(self.client.get('/api/stats/').status_code,403)
 def test_admin_login_required(self):self.assertEqual(self.client.get('/admin/').status_code,302)
 def test_weak_password_rejected(self):self.assertEqual(self.client.post('/api/auth/register/',{'username':'newplayer','password':'12345678'}).status_code,400)
 def test_register_login_logout(self):
  r=self.client.post('/api/auth/register/',{'username':'newplayer','password':'PlanetSpace42!'});self.assertEqual(r.status_code,201);self.assertEqual(self.client.get('/api/me/').data['user']['username'],'newplayer');self.assertEqual(self.client.post('/api/auth/logout/').status_code,200)
 def test_csrf_enforced(self):
  c=APIClient(enforce_csrf_checks=True);self.assertEqual(c.post('/api/auth/login/',{'username':'player','password':'LongSpacePass42!'}).status_code,403)
 def test_profile_only_self(self):self.auth();self.assertEqual(self.client.patch('/api/profile/',{'display_name':'Player One'}).data['display_name'],'Player One')
 def test_view_history(self):self.auth();self.client.post('/api/games/official-game/viewed/');self.assertEqual(len(self.client.get('/api/library/').data['history']),1)
 def test_provider_requires_key(self):
  from .providers import RAWG
  with patch.dict('os.environ',{},clear=True):
   with self.assertRaises(ValueError):RAWG().search('test')
 def test_collection_nested_games_and_duplicate_name(self):
  self.auth()
  from .models import Game
  g=Game.objects.first()
  r=self.client.post('/api/collections/',{'name':'Mine','games':[g.id]})
  self.assertEqual(r.status_code,201)
  self.assertEqual(len(r.data['games_detail']),1)
  self.assertEqual(self.client.post('/api/collections/',{'name':'Mine','games':[]}).status_code,400)
 def test_avatar_upload_multipart(self):
  import io,tempfile
  from PIL import Image
  from django.core.files.uploadedfile import SimpleUploadedFile
  from django.test import override_settings
  self.auth()
  b=io.BytesIO();Image.new('RGB',(8,8),'blue').save(b,'PNG')
  with tempfile.TemporaryDirectory() as d,override_settings(MEDIA_ROOT=d):
   r=self.client.patch('/api/profile/',{'avatar':SimpleUploadedFile('a.png',b.getvalue(),'image/png')},format='multipart')
   self.assertEqual(r.status_code,200);self.assertTrue(r.data['avatar'])
 def test_admin_dashboard_stats_panel(self):
  from django.contrib.auth.models import User
  User.objects.create_superuser('boss','b@example.com','Pass-12345-xyz')
  self.client.logout();self.client.login(username='boss',password='Pass-12345-xyz')
  r=self.client.get('/admin/')
  self.assertEqual(r.status_code,200);self.assertContains(r,'nidal-stats')
  self.assertEqual(self.client.get('/api/stats/').status_code,200)
