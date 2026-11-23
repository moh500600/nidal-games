from django.core.management.base import BaseCommand,CommandError
from catalog.providers import sync_steam
import time
class Command(BaseCommand):
 help='Fetch current official Steam catalog records. Does not download game files or accept store terms.'
 def add_arguments(self,p):p.add_argument('appids',nargs='+',type=int)
 def handle(self,*args,**o):
  failed=0
  for appid in o['appids']:
   try:self.stdout.write('Imported: '+sync_steam(appid).title)
   except Exception as e:failed+=1;self.stderr.write('Failed app '+str(appid)+': '+str(e))
   time.sleep(1)
  if failed:raise CommandError(str(failed)+' imports failed')
