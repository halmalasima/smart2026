from __future__ import annotations

from datetime import timedelta

from django.utils import timezone

from dashboard.models import SubscriptionPlan, UserSubscription


TRIAL_PLAN_NAME = "تجربة مجانية 3 أيام"


def ensure_trial_subscription(user, days: int = 3) -> UserSubscription:
    now = timezone.now()

    plan, _ = SubscriptionPlan.objects.get_or_create(
        name=TRIAL_PLAN_NAME,
        defaults={
            "price": 0,
            "duration_days": days,
            "features": {"trial": True},
            "is_active": True,
        },
    )

    if plan.duration_days != days:
        plan.duration_days = days
        plan.save(update_fields=["duration_days"])

    end_date = now + timedelta(days=days)

    sub, _ = UserSubscription.objects.update_or_create(
        user=user,
        defaults={
            "plan": plan,
            "start_date": now,
            "end_date": end_date,
            "is_active": True,
        },
    )

    try:
        profile = user.profile
        profile.subscription_plan = "trial"
        profile.is_trial = True
        profile.subscription_expiry = end_date
        profile.save(update_fields=["subscription_plan", "is_trial", "subscription_expiry"])
    except Exception:
        pass

    return sub


def get_active_subscription(user) -> UserSubscription | None:
    now = timezone.now()
    sub = UserSubscription.objects.filter(user=user, is_active=True).select_related("plan").first()
    if not sub:
        return None

    if sub.end_date and sub.end_date >= now:
        return sub

    sub.is_active = False
    sub.save(update_fields=["is_active"])

    try:
        profile = user.profile
        profile.is_trial = False
        profile.save(update_fields=["is_trial"])
    except Exception:
        pass

    return None


def is_trial_active(user) -> bool:
    now = timezone.now()
    try:
        profile = user.profile
        if profile.subscription_expiry and profile.subscription_expiry >= now and profile.is_trial:
            return True
    except Exception:
        pass

    sub = get_active_subscription(user)
    if not sub or not sub.plan:
        return False
    if sub.plan.name == TRIAL_PLAN_NAME and sub.end_date and sub.end_date >= now:
        return True
    return False
