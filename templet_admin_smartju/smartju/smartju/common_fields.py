"""
Common serializer fields to avoid circular imports
"""
from rest_framework import serializers


class LawsuitPrimaryKeyField(serializers.PrimaryKeyRelatedField):
    """Custom field that sets queryset lazily to avoid circular imports"""
    def get_queryset(self):
        from lawsuits.models import Lawsuit
        return Lawsuit.objects.all()

