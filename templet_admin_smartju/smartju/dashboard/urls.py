from django.urls import path
from . import views

urlpatterns = [
    path('home/', views.dashboard_home, name='dashboard-home'),
    path('portal/', views.web_portal, name='web-portal'),
]

