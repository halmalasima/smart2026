from django.core.management.base import BaseCommand
from django.db import transaction

from control_panel.models import ServiceDefinition


class Command(BaseCommand):
    help = "Sync (create/update) ServiceDefinition rows from a built-in manifest."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Do not write to database; only show what would change.",
        )

    def handle(self, *args, **options):
        dry_run = bool(options.get("dry_run"))

        # NOTE: keys are Flutter routes. Keep them stable.
        manifest = [
            {
                "key": "/services",
                "name_ar": "خدماتنا",
                "name_en": "Services",
                "icon": "apps",
                "category": "general",
                "is_premium": False,
                "sort_order": 10,
            },
            {
                "key": "/legal-library",
                "name_ar": "المكتبة القانونية",
                "name_en": "Legal Library",
                "icon": "book",
                "category": "legal",
                "is_premium": False,
                "sort_order": 20,
            },
            {
                "key": "/chat",
                "name_ar": "المساعد الذكي",
                "name_en": "Smart Assistant",
                "icon": "message",
                "category": "ai",
                "is_premium": False,
                "sort_order": 30,
            },
            {
                "key": "/case-analysis",
                "name_ar": "تحليل القضايا بالذكاء الاصطناعي",
                "name_en": "AI Case Analysis",
                "icon": "sparkles",
                "category": "ai",
                "is_premium": True,
                "sort_order": 40,
            },
            {
                "key": "/lawsuits",
                "name_ar": "أرشيف القضايا",
                "name_en": "Lawsuits Archive",
                "icon": "folder",
                "category": "legal",
                "is_premium": True,
                "sort_order": 50,
            },
            {
                "key": "/case-management",
                "name_ar": "إدارة القضايا",
                "name_en": "Case Management",
                "icon": "briefcase",
                "category": "legal",
                "is_premium": True,
                "sort_order": 60,
            },
            {
                "key": "/notifications",
                "name_ar": "الإشعارات",
                "name_en": "Notifications",
                "icon": "bell",
                "category": "communication",
                "is_premium": False,
                "sort_order": 70,
            },
            {
                "key": "/procedures",
                "name_ar": "دليل الإجراءات",
                "name_en": "Procedures Guide",
                "icon": "book-2",
                "category": "legal",
                "is_premium": False,
                "sort_order": 80,
            },
            {
                "key": "/forms",
                "name_ar": "النماذج القانونية",
                "name_en": "Legal Forms",
                "icon": "file-text",
                "category": "legal",
                "is_premium": True,
                "sort_order": 90,
            },
            {
                "key": "/consultations",
                "name_ar": "الاستشارات عن بُعد",
                "name_en": "Remote Consultations",
                "icon": "video",
                "category": "communication",
                "is_premium": True,
                "sort_order": 100,
            },
            {
                "key": "/inquiries",
                "name_ar": "الاستعلامات",
                "name_en": "Inquiries",
                "icon": "search",
                "category": "general",
                "is_premium": False,
                "sort_order": 110,
            },
            {
                "key": "/daily-sessions",
                "name_ar": "الجلسات اليومية",
                "name_en": "Daily Sessions",
                "icon": "calendar",
                "category": "legal",
                "is_premium": False,
                "sort_order": 120,
            },
        ]

        created = 0
        updated = 0

        self.stdout.write(self.style.NOTICE(f"Syncing {len(manifest)} services (dry_run={dry_run})..."))

        with transaction.atomic():
            for row in manifest:
                key = row["key"].strip()
                defaults = {
                    "name_ar": row.get("name_ar", "").strip(),
                    "name_en": row.get("name_en", "").strip(),
                    "description": row.get("description", ""),
                    "icon": row.get("icon", "settings"),
                    "category": row.get("category", "general"),
                    "is_active": bool(row.get("is_active", True)),
                    "is_premium": bool(row.get("is_premium", False)),
                    "sort_order": int(row.get("sort_order", 0)),
                }

                obj = ServiceDefinition.objects.filter(key=key).first()
                if obj is None:
                    created += 1
                    if not dry_run:
                        ServiceDefinition.objects.create(key=key, **defaults)
                    continue

                changed = False
                for k, v in defaults.items():
                    if getattr(obj, k) != v:
                        setattr(obj, k, v)
                        changed = True

                if changed:
                    updated += 1
                    if not dry_run:
                        obj.save()

            if dry_run:
                transaction.set_rollback(True)

        self.stdout.write(self.style.SUCCESS(f"Done. created={created}, updated={updated}"))
