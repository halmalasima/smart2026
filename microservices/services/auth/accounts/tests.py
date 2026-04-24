from django.test import TestCase
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from .models import UserProfile


class UserProfileModelTest(TestCase):
    """
    Test cases for UserProfile model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123',
            first_name='Test',
            last_name='User'
        )
    
    def test_user_profile_auto_creation(self):
        """Test that UserProfile is created automatically when User is created"""
        # UserProfile should be created automatically via signal
        self.assertTrue(hasattr(self.user, 'profile'))
        self.assertIsNotNone(self.user.profile)
        self.assertEqual(self.user.profile.role, UserProfile.ROLE_CITIZEN)
    
    def test_user_profile_creation(self):
        """Test creating UserProfile manually"""
        user2 = User.objects.create_user(
            username='testuser2',
            email='test2@example.com',
            password='testpass123'
        )
        profile = UserProfile.objects.get(user=user2)
        self.assertEqual(profile.user, user2)
        self.assertEqual(profile.role, UserProfile.ROLE_CITIZEN)
    
    def test_user_profile_roles(self):
        """Test UserProfile role choices"""
        profile = self.user.profile
        profile.role = UserProfile.ROLE_JUDGE
        profile.save()
        self.assertTrue(profile.is_judge)
        self.assertFalse(profile.is_lawyer)
        
        profile.role = UserProfile.ROLE_LAWYER
        profile.save()
        self.assertTrue(profile.is_lawyer)
        self.assertFalse(profile.is_judge)
    
    def test_user_profile_national_id_unique(self):
        """Test that national_id must be unique"""
        profile1 = self.user.profile
        profile1.national_id = '123456789'
        profile1.save()
        
        user2 = User.objects.create_user(
            username='testuser2',
            email='test2@example.com',
            password='testpass123'
        )
        profile2 = user2.profile
        profile2.national_id = '123456789'
        
        with self.assertRaises(ValidationError):
            profile2.full_clean()
    
    def test_user_profile_str(self):
        """Test UserProfile string representation"""
        profile = self.user.profile
        profile.role = UserProfile.ROLE_JUDGE
        profile.save()
        expected_str = f'{self.user.username} - {profile.get_role_display()}'
        self.assertEqual(str(profile), expected_str)
    
    def test_user_profile_cascade_delete(self):
        """Test that UserProfile is deleted when User is deleted"""
        user_id = self.user.id
        profile_id = self.user.profile.id
        
        self.user.delete()
        
        self.assertFalse(UserProfile.objects.filter(id=profile_id).exists())
        self.assertFalse(User.objects.filter(id=user_id).exists())
    
    def test_user_profile_properties(self):
        """Test UserProfile property methods"""
        profile = self.user.profile
        
        profile.role = UserProfile.ROLE_JUDGE
        self.assertTrue(profile.is_judge)
        
        profile.role = UserProfile.ROLE_LAWYER
        self.assertTrue(profile.is_lawyer)
        
        profile.role = UserProfile.ROLE_NOTARY
        self.assertTrue(profile.is_notary)
        
        profile.role = UserProfile.ROLE_CITIZEN
        self.assertTrue(profile.is_citizen)
        
        profile.role = UserProfile.ROLE_ADMIN
        self.assertTrue(profile.is_admin_role)
