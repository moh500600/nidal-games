from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator,MaxValueValidator,FileExtensionValidator
class Category(models.Model):
 name=models.CharField(max_length=80,unique=True);name_ar=models.CharField(max_length=80);slug=models.SlugField(unique=True)
 def __str__(self): return self.name
class Game(models.Model):
 title=models.CharField(max_length=180);slug=models.SlugField(unique=True);description=models.TextField();description_ar=models.TextField(blank=True)
 categories=models.ManyToManyField(Category,related_name='games');cover=models.URLField(blank=True);cover_upload=models.ImageField(upload_to='covers/',blank=True,validators=[FileExtensionValidator(['jpg','jpeg','png','webp'])])
 screenshots=models.JSONField(default=list,blank=True);trailer=models.URLField(blank=True);developer=models.CharField(max_length=180,blank=True);publisher=models.CharField(max_length=180,blank=True)
 release_date=models.DateField(null=True,blank=True);platforms=models.JSONField(default=list);requirements=models.JSONField(default=dict,blank=True);size_label=models.CharField(max_length=80,blank=True)
 official_url=models.URLField();store_url=models.URLField(blank=True);download_url=models.URLField(blank=True);download_permitted=models.BooleanField(default=False)
 is_free=models.BooleanField(default=False);featured=models.BooleanField(default=False);discount_percent=models.PositiveSmallIntegerField(default=0,validators=[MaxValueValidator(100)])
 source=models.CharField(max_length=40,default='official');source_id=models.CharField(max_length=80,blank=True);source_url=models.URLField(blank=True);source_checked_at=models.DateTimeField(null=True,blank=True)
 published=models.BooleanField(default=True);created_at=models.DateTimeField(auto_now_add=True);updated_at=models.DateTimeField(auto_now=True)
 def __str__(self): return self.title
class Profile(models.Model):
 user=models.OneToOneField(User,on_delete=models.CASCADE,related_name='profile');display_name=models.CharField(max_length=120,blank=True);bio=models.CharField(max_length=500,blank=True);avatar=models.ImageField(upload_to='avatars/',blank=True,validators=[FileExtensionValidator(['jpg','jpeg','png','webp'])]);language=models.CharField(max_length=2,default='ar',choices=[('ar','Arabic'),('en','English')])
class Favorite(models.Model):
 user=models.ForeignKey(User,on_delete=models.CASCADE);game=models.ForeignKey(Game,on_delete=models.CASCADE);created_at=models.DateTimeField(auto_now_add=True)
 class Meta: constraints=[models.UniqueConstraint(fields=['user','game'],name='unique_favorite')]
class Review(models.Model):
 user=models.ForeignKey(User,on_delete=models.CASCADE);game=models.ForeignKey(Game,on_delete=models.CASCADE,related_name='reviews');rating=models.PositiveSmallIntegerField(validators=[MinValueValidator(1),MaxValueValidator(5)]);text=models.CharField(max_length=2000,blank=True);created_at=models.DateTimeField(auto_now_add=True)
 class Meta: constraints=[models.UniqueConstraint(fields=['user','game'],name='unique_review')]
class Collection(models.Model):
 user=models.ForeignKey(User,on_delete=models.CASCADE);name=models.CharField(max_length=100);games=models.ManyToManyField(Game,blank=True)
 class Meta: constraints=[models.UniqueConstraint(fields=['user','name'],name='unique_collection')]
class Download(models.Model):
 user=models.ForeignKey(User,on_delete=models.CASCADE);game=models.ForeignKey(Game,on_delete=models.CASCADE);status=models.CharField(max_length=16,default='opened',choices=[('opened','Official page opened'),('downloaded','Marked downloaded by user')]);created_at=models.DateTimeField(auto_now_add=True)
 class Meta: constraints=[models.UniqueConstraint(fields=['user','game'],name='unique_download')]
class ActivityLog(models.Model):
 user=models.ForeignKey(User,on_delete=models.CASCADE);game=models.ForeignKey(Game,on_delete=models.SET_NULL,null=True,blank=True);action=models.CharField(max_length=80);created_at=models.DateTimeField(auto_now_add=True)
 class Meta: ordering=['-created_at']
class Announcement(models.Model):
 title=models.CharField(max_length=180);title_ar=models.CharField(max_length=180,blank=True);body=models.TextField(blank=True);active=models.BooleanField(default=True);is_ad=models.BooleanField(default=False)
