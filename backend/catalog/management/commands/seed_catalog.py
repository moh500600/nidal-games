from django.core.management.base import BaseCommand
from catalog.models import Category,Game
class Command(BaseCommand):
 help='Idempotent minimal offline sample catalog. No invented prices, reviews or users.'
 def handle(self,*args,**options):
  names=[('Action','أكشن'),('Adventure','مغامرات'),('Shooting','تصويب'),('Racing','سباقات'),('Sports','رياضة'),('Strategy','استراتيجية'),('Simulation','محاكاة'),('Horror','رعب'),('RPG','تقمص أدوار'),('Puzzle','ألغاز'),('Multiplayer','متعددة اللاعبين'),('Offline Games','دون اتصال')]
  from django.utils.text import slugify
  for en,ar in names:Category.objects.update_or_create(slug=slugify(en),defaults={'name':en,'name_ar':ar})
  games=[('0 A.D.','0-ad','A free, open-source historical real-time strategy game.','لعبة استراتيجية تاريخية مجانية ومفتوحة المصدر.','https://play0ad.com/','Strategy'),('SuperTuxKart','supertuxkart','An open-source kart racing game.','لعبة سباقات كارتينج مفتوحة المصدر.','https://supertuxkart.net/','Racing'),('The Battle for Wesnoth','wesnoth','A free, open-source turn-based strategy game in a fantasy world.','لعبة استراتيجية خيالية مجانية ومفتوحة المصدر بنظام الأدوار.','https://www.wesnoth.org/','Strategy')]
  for title,slug,en,ar,url,category in games:
   g,_=Game.objects.get_or_create(slug=slug,defaults={'title':title,'description':en,'description_ar':ar,'official_url':url,'source_url':url,'is_free':True,'platforms':['PC'],'source':'official sample'})
   g.categories.add(Category.objects.get(name=category))
  self.stdout.write('Sample catalog ready. Run sync_steam for live official metadata.')
