from django.contrib import admin
from django.urls import path,include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework.routers import DefaultRouter
from catalog import views as v
router=DefaultRouter()
for name,view in [('games',v.GameView),('categories',v.CategoryView),('auth',v.AuthView),('collections',v.CollectionView),('downloads',v.DownloadView)]:router.register(name,view,basename=name)
urlpatterns=[path('admin/',admin.site.urls),path('api/csrf/',v.csrf),path('api/me/',v.me),path('api/library/',v.library),path('api/recommendations/',v.recommendations),path('api/profile/',v.profile),path('api/activity/',v.activity),path('api/stats/',v.stats),path('api/announcements/',v.announcements),path('api/',include(router.urls))]
if settings.DEBUG:urlpatterns+=static(settings.MEDIA_URL,document_root=settings.MEDIA_ROOT)
