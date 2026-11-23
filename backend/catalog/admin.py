from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin
from .models import *
@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
 list_display=['title','source','is_free','featured','published','updated_at'];list_filter=['source','is_free','featured','published','categories'];search_fields=['title','developer'];prepopulated_fields={'slug':['title']};filter_horizontal=['categories']
@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
 list_display=['name','name_ar'];prepopulated_fields={'slug':['name']}
@admin.register(ActivityLog)
class LogAdmin(admin.ModelAdmin):
 list_display=['user','action','game','created_at'];readonly_fields=['user','action','game','created_at']
 def has_add_permission(self,request): return False
for model in [Profile,Favorite,Review,Collection,Download,Announcement]: admin.site.register(model)
admin.site.site_header='Nidal Games • Control Center'
admin.site.site_title='Nidal Admin'

from django.db.models import Count
_orig_index=admin.site.index
def _index(request,extra_context=None):
 extra=dict(extra_context or {})
 extra['nidal_stats']=[('USERS',User.objects.count()),('GAMES',Game.objects.count()),('PUBLISHED',Game.objects.filter(published=True).count()),('FEATURED',Game.objects.filter(featured=True).count()),('FAVORITES',Favorite.objects.count()),('REVIEWS',Review.objects.count()),('DOWNLOAD ACTIONS',Download.objects.count()),('ACTIVITY EVENTS',ActivityLog.objects.count())]
 return _orig_index(request,extra)
admin.site.index=_index
admin.site.index_template='admin/nidal_index.html'
