from django.urls import path
from .views import register_user, create_sub_account

urlpatterns = [
    path('', register_user, name='register'),
    path('create-sub-account/', create_sub_account, name='create_sub_account'),
]

