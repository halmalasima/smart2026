"""
Helpers for user role resolution — works with both:
  - Full Django User (with profile) from auth service
  - TokenUser (stateless JWT) from other microservices
"""


def get_user_role(user) -> str:
    """
    Return the role string for a user object.

    Priority:
      1. JWT token claim 'role'  (TokenUser / JWTStatelessUserAuthentication)
      2. user.profile.role       (full Django User loaded from DB)
      3. 'admin' if is_superuser
      4. 'lawyer' as safe fallback
    """
    if getattr(user, 'is_superuser', False):
        return 'admin'
    # Token-based claim (simplejwt TokenUser exposes custom claims via __getattr__)
    try:
        role = user.role  # works for TokenUser with custom claims
        if role:
            return role
    except AttributeError:
        pass
    # Profile-based (full DB user)
    try:
        profile = user.profile
        if profile and getattr(profile, 'role', None):
            return profile.role
    except Exception:
        pass
    return 'lawyer'


def get_user_id(user) -> int:
    """Return the integer PK of a user (TokenUser or Django User)."""
    return getattr(user, 'id', None) or getattr(user, 'user_id', None)
