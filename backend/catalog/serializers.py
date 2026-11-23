from rest_framework import serializers
from django.db.models import Avg
from .models import *
class CategorySerializer(serializers.ModelSerializer):
 class Meta: model=Category;fields='__all__'
class GameSerializer(serializers.ModelSerializer):
 categories=CategorySerializer(many=True,read_only=True)
 rating=serializers.SerializerMethodField();review_count=serializers.SerializerMethodField();cover=serializers.SerializerMethodField()
 def get_rating(self,o): return o.reviews.aggregate(value=Avg('rating'))['value']
 def get_review_count(self,o): return o.reviews.count()
 def get_cover(self,o):
  if o.cover_upload: return self.context['request'].build_absolute_uri(o.cover_upload.url)
  return o.cover
 class Meta: model=Game;fields='__all__'
class ReviewSerializer(serializers.ModelSerializer):
 username=serializers.CharField(source='user.username',read_only=True)
 class Meta: model=Review;fields=['id','game','username','rating','text','created_at'];read_only_fields=['id','created_at']
class CollectionSerializer(serializers.ModelSerializer):
 games_detail=GameSerializer(source='games',many=True,read_only=True)
 def validate_name(self,v):
  v=v.strip()
  u=self.context['request'].user
  qs=Collection.objects.filter(user=u,name=v)
  if self.instance: qs=qs.exclude(pk=self.instance.pk)
  if not v or qs.exists(): raise serializers.ValidationError('Collection name is empty or already exists')
  return v
 class Meta: model=Collection;fields=['id','name','games','games_detail']
class DownloadSerializer(serializers.ModelSerializer):
 game_detail=GameSerializer(source='game',read_only=True)
 class Meta: model=Download;fields=['id','game','game_detail','status','created_at'];read_only_fields=['id','game','created_at']
class ProfileSerializer(serializers.ModelSerializer):
 class Meta: model=Profile;fields=['display_name','bio','avatar','language']
 def validate_avatar(self,file):
  if file.size>2*1024*1024: raise serializers.ValidationError('Maximum avatar size is 2 MB')
  return file
class ActivitySerializer(serializers.ModelSerializer):
 game_title=serializers.CharField(source='game.title',default=None,read_only=True)
 class Meta: model=ActivityLog;fields=['id','game','game_title','action','created_at']
