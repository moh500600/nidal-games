from django.contrib.auth import authenticate,login,logout
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import IntegrityError,transaction
from django.db.models import Q,Count
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.views.decorators.csrf import csrf_protect
from django.utils.decorators import method_decorator
from rest_framework import viewsets,status
from rest_framework.decorators import action,api_view,permission_classes
from rest_framework.permissions import AllowAny,IsAuthenticated,IsAdminUser
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from .models import *
from .serializers import *
def log(user,action,game=None): ActivityLog.objects.create(user=user,action=action,game=game)
@api_view(['GET'])
@permission_classes([AllowAny])
def csrf(request): return Response({'csrfToken':get_token(request)})
@api_view(['GET'])
@permission_classes([AllowAny])
def me(request):
 if not request.user.is_authenticated: return Response({'user':None})
 p,_=Profile.objects.get_or_create(user=request.user)
 return Response({'user':{'id':request.user.id,'username':request.user.username,'email':request.user.email,'is_staff':request.user.is_staff,'profile':ProfileSerializer(p,context={'request':request}).data}})
@method_decorator(csrf_protect,name='dispatch')
class AuthView(viewsets.ViewSet):
 permission_classes=[AllowAny];throttle_classes=[ScopedRateThrottle];throttle_scope='login'
 @action(detail=False,methods=['post'])
 def register(self,request):
  username=str(request.data.get('username','')).strip();password=request.data.get('password','');email=str(request.data.get('email','')).strip()
  import re
  from django.core.validators import validate_email
  if not re.fullmatch(r'[\w.@+-]{3,150}',username): return Response({'detail':'Username must be 3-150 letters, numbers or . @ + - _'},status=400)
  try:
   if email: validate_email(email)
   validate_password(password,User(username=username,email=email))
  except ValidationError as e: return Response({'detail':e.messages},status=400)
  try:
   with transaction.atomic():
    user=User.objects.create_user(username=username,password=password,email=email);Profile.objects.create(user=user)
  except IntegrityError: return Response({'detail':'Username already exists'},status=400)
  login(request,user);log(user,'registered');return Response({'ok':True},status=201)
 @action(detail=False,methods=['post'],url_path='login')
 def signin(self,request):
  user=authenticate(request,username=request.data.get('username'),password=request.data.get('password'))
  if not user: return Response({'detail':'Invalid credentials'},status=400)
  login(request,user);log(user,'login');return Response({'ok':True})
 @action(detail=False,methods=['post'],url_path='logout')
 def signout(self,request): logout(request);return Response({'ok':True})
class GameView(viewsets.ReadOnlyModelViewSet):
 serializer_class=GameSerializer;lookup_field='slug';permission_classes=[AllowAny]
 def get_queryset(self):
  q=Game.objects.filter(published=True).prefetch_related('categories','reviews');p=self.request.query_params
  if p.get('search'): q=q.filter(Q(title__icontains=p['search'])|Q(description__icontains=p['search'])|Q(description_ar__icontains=p['search'])|Q(developer__icontains=p['search']))
  if p.get('category'): q=q.filter(categories__slug=p['category'])
  if p.get('free')=='1':q=q.filter(is_free=True)
  if p.get('discount')=='1':q=q.filter(discount_percent__gt=0)
  if p.get('featured')=='1':q=q.filter(featured=True)
  if p.get('platform'): q=q.filter(platforms__icontains=p['platform'])
  order=p.get('sort','newest');q=q.annotate(popularity=Count('favorite',distinct=True)+Count('reviews',distinct=True))
  return q.order_by({'newest':'-created_at','title':'title','popular':'-popularity','release':'-release_date'}.get(order,'-created_at'),'id').distinct()
 @action(detail=True,methods=['post'],permission_classes=[IsAuthenticated])
 def viewed(self,request,slug=None):
  game=self.get_object();log(request.user,'viewed',game);return Response({'ok':True})
 @action(detail=True,methods=['post','delete'],permission_classes=[IsAuthenticated])
 def favorite(self,request,slug=None):
  game=self.get_object()
  if request.method=='DELETE':Favorite.objects.filter(user=request.user,game=game).delete();return Response(status=204)
  Favorite.objects.get_or_create(user=request.user,game=game);log(request.user,'favorited',game);return Response({'ok':True})
 @action(detail=True,methods=['post'],permission_classes=[IsAuthenticated])
 def open_source(self,request,slug=None):
  game=self.get_object();url=game.download_url if game.download_permitted and game.download_url else game.store_url or game.official_url
  Download.objects.get_or_create(user=request.user,game=game);log(request.user,'opened_official_source',game)
  return Response({'url':url,'progress_supported':False,'notice':'External official page; download progress cannot be observed by this app.'})
 @action(detail=True,methods=['get'])
 def similar(self,request,slug=None):
  game=self.get_object();q=Game.objects.filter(published=True,categories__in=game.categories.all()).exclude(pk=game.pk).distinct()[:8]
  return Response(GameSerializer(q,many=True,context={'request':request}).data)
 @action(detail=True,methods=['get','post'],permission_classes=[AllowAny])
 def reviews(self,request,slug=None):
  game=self.get_object()
  if request.method=='GET':return Response(ReviewSerializer(game.reviews.select_related('user'),many=True).data)
  if not request.user.is_authenticated:return Response({'detail':'Sign in required'},status=403)
  s=ReviewSerializer(data={**request.data,'game':game.id});s.is_valid(raise_exception=True)
  Review.objects.update_or_create(user=request.user,game=game,defaults={'rating':s.validated_data['rating'],'text':s.validated_data.get('text','')});log(request.user,'reviewed',game)
  return Response({'ok':True},status=201)
class CategoryView(viewsets.ReadOnlyModelViewSet):
 queryset=Category.objects.all().order_by('name');serializer_class=CategorySerializer;pagination_class=None;permission_classes=[AllowAny]
class CollectionView(viewsets.ModelViewSet):
 serializer_class=CollectionSerializer;permission_classes=[IsAuthenticated]
 def get_queryset(self):return Collection.objects.filter(user=self.request.user)
 def perform_create(self,s):s.save(user=self.request.user)
class DownloadView(viewsets.ReadOnlyModelViewSet):
 serializer_class=DownloadSerializer;permission_classes=[IsAuthenticated]
 def get_queryset(self):return Download.objects.filter(user=self.request.user).select_related('game').order_by('-created_at')
 @action(detail=True,methods=['post'])
 def complete(self,request,pk=None):
  d=self.get_object();d.status='downloaded';d.save();return Response({'ok':True})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def library(request):
 fav=Game.objects.filter(favorite__user=request.user,published=True)
 ids=ActivityLog.objects.filter(user=request.user,action='viewed',game__isnull=False).values_list('game_id',flat=True).distinct()[:30]
 return Response({'favorites':GameSerializer(fav,many=True,context={'request':request}).data,'history':GameSerializer(Game.objects.filter(pk__in=list(ids),published=True),many=True,context={'request':request}).data})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def recommendations(request):
 cats=Category.objects.filter(games__favorite__user=request.user).distinct()
 games=Game.objects.filter(published=True)
 if cats.exists():games=games.filter(categories__in=cats)
 games=games.exclude(favorite__user=request.user).distinct()[:12]
 return Response(GameSerializer(games,many=True,context={'request':request}).data)
@api_view(['GET','PATCH'])
@permission_classes([IsAuthenticated])
def profile(request):
 p,_=Profile.objects.get_or_create(user=request.user)
 if request.method=='PATCH':
  s=ProfileSerializer(p,data=request.data,partial=True,context={'request':request});s.is_valid(raise_exception=True);s.save()
 return Response(ProfileSerializer(p,context={'request':request}).data)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def activity(request):return Response(ActivitySerializer(ActivityLog.objects.filter(user=request.user).select_related('game')[:100],many=True).data)
@api_view(['GET'])
@permission_classes([IsAdminUser])
def stats(request):return Response({'users':User.objects.count(),'games':Game.objects.count(),'favorites':Favorite.objects.count(),'reviews':Review.objects.count(),'source_opens':Download.objects.count(),'activity':ActivityLog.objects.count()})
@api_view(['GET'])
@permission_classes([AllowAny])
def announcements(request):return Response(list(Announcement.objects.filter(active=True).values('id','title','title_ar','body','is_ad')))
