"""Server-side providers. No provider secrets are returned to clients."""
import json,os,urllib.request,urllib.parse,html,re
from django.utils import timezone
from django.utils.text import slugify
from .models import Game,Category
def fetch_json(url,body=None,headers=None):
 req=urllib.request.Request(url,data=body,headers={'User-Agent':'NidalGames/1.0 catalog-import',**(headers or {})})
 with urllib.request.urlopen(req,timeout=25) as r: return json.load(r)
def plain(s):return html.unescape(re.sub('<[^>]+>',' ',s or '')).strip()
def sync_steam(appid):
 appid=str(int(appid));url='https://store.steampowered.com/api/appdetails?'+urllib.parse.urlencode({'appids':appid,'l':'english','cc':'US'})
 item=fetch_json(url).get(appid,{})
 if not item.get('success'):raise ValueError('Steam did not return this app')
 d=item['data'];store='https://store.steampowered.com/app/'+appid+'/'
 reqs=d.get('pc_requirements') or {};reqs=reqs if isinstance(reqs,dict) else {}
 movies=d.get('movies') or [];trailer=''
 if movies:
  m=movies[0];trailer=(m.get('mp4') or {}).get('max') or (m.get('webm') or {}).get('max') or m.get('hls_h264') or ''
 date=None
 from datetime import datetime
 for fmt in ['%d %b, %Y','%b %d, %Y']:
  try:date=datetime.strptime(d.get('release_date',{}).get('date',''),fmt).date();break
  except ValueError:pass
 game,_=Game.objects.update_or_create(source='steam',source_id=appid,defaults={'slug':slugify(d['name'])+'-'+appid,'title':d['name'],'description':plain(d.get('detailed_description') or d.get('short_description')),'cover':d.get('header_image',''),'screenshots':[x['path_full'] for x in d.get('screenshots',[])[:8]],'trailer':trailer,'developer':', '.join(d.get('developers',[])),'publisher':', '.join(d.get('publishers',[])),'release_date':date,'platforms':[k for k,v in d.get('platforms',{}).items() if v],'requirements':{k:plain(v) for k,v in reqs.items()},'official_url':store,'store_url':store,'download_url':'','download_permitted':False,'is_free':d.get('is_free',False),'discount_percent':0,'source_url':url,'source_checked_at':timezone.now()})
 names=[g['description'] for g in d.get('genres',[])]+[c['description'] for c in d.get('categories',[]) if c['description'] in ['Multi-player','Single-player']]
 for name in names:
  if name=='Free To Play':continue
  if name=='Multi-player':name='Multiplayer'
  cat,_=Category.objects.get_or_create(slug=slugify(name),defaults={'name':name,'name_ar':name});game.categories.add(cat)
 return game
class RAWG:
 def search(self,query):
  key=os.environ.get('RAWG_API_KEY')
  if not key:raise ValueError('RAWG_API_KEY is not configured')
  return fetch_json('https://api.rawg.io/api/games?'+urllib.parse.urlencode({'key':key,'search':query,'page_size':10}))
class IGDB:
 def search(self,query):
  client=os.environ.get('IGDB_CLIENT_ID');secret=os.environ.get('IGDB_CLIENT_SECRET')
  if not client or not secret:raise ValueError('IGDB credentials are not configured')
  token=fetch_json('https://id.twitch.tv/oauth2/token',urllib.parse.urlencode({'client_id':client,'client_secret':secret,'grant_type':'client_credentials'}).encode())['access_token']
  # JSON string escaping prevents query injection in the APICalypse string literal.
  body=('search '+json.dumps(query)+'; fields name,summary,cover.url,first_release_date; limit 10;').encode()
  return fetch_json('https://api.igdb.com/v4/games',body,{'Client-ID':client,'Authorization':'Bearer '+token,'Content-Type':'text/plain'})
