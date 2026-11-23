from django.core.management.base import BaseCommand,CommandError
from catalog.providers import RAWG,IGDB
import json
class Command(BaseCommand):
 help='Operator-only provider search; secrets remain server-side. Verify provider license first.'
 def add_arguments(self,p):p.add_argument('provider',choices=['rawg','igdb']);p.add_argument('query')
 def handle(self,*args,**o):
  try:self.stdout.write(json.dumps((RAWG() if o['provider']=='rawg' else IGDB()).search(o['query']),ensure_ascii=False,indent=2))
  except Exception as e:raise CommandError(str(e))
