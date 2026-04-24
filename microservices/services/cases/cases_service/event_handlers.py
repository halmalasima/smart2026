"""
Event handlers for cases-service.
Listens to Redis events from hearings-service and documents-service
to create CaseFileItem entries automatically.
"""
import logging
from smartjudi_common.events import EventListener

logger = logging.getLogger(__name__)


def _handle_hearings_event(event_type: str, payload: dict):
    """Dispatcher for hearings channel events."""
    if event_type == 'hearing.scheduled':
        _create_case_file_for_hearing(payload)


def _handle_documents_event(event_type: str, payload: dict):
    """Dispatcher for documents channel events."""
    if event_type == 'attachment.created':
        _create_case_file_for_attachment(payload)


def _create_case_file_for_hearing(payload: dict):
    """Create a CaseFileItem when a hearing is scheduled (event from hearings-service)."""
    try:
        from lawsuits.models import Lawsuit
        from lawsuits.models_casefile import CaseFileItem

        lawsuit_id = payload.get('lawsuit_id')
        if not lawsuit_id:
            return

        try:
            lawsuit = Lawsuit.objects.get(pk=lawsuit_id)
        except Lawsuit.DoesNotExist:
            logger.warning('Lawsuit %s not found for hearing event', lawsuit_id)
            return

        hearing_id = payload.get('hearing_id')
        already_exists = CaseFileItem.objects.filter(
            lawsuit=lawsuit,
            related_object_id=hearing_id,
            related_object_type='hearing',
        ).exists()

        if not already_exists:
            CaseFileItem.objects.create(
                lawsuit=lawsuit,
                item_type=CaseFileItem.TYPE_HEARING_RECORD,
                title=f"جلسة - {payload.get('hearing_date', '')}",
                description='',
                related_object_id=hearing_id,
                related_object_type='hearing',
                sort_order=100,
            )
            logger.info('CaseFileItem created for hearing %s', hearing_id)
    except Exception as e:
        logger.error('Error handling hearing.scheduled event: %s', e)


def _create_case_file_for_attachment(payload: dict):
    """Create a CaseFileItem when an attachment is uploaded (event from documents-service)."""
    try:
        from lawsuits.models import Lawsuit
        from lawsuits.models_casefile import CaseFileItem

        lawsuit_id = payload.get('lawsuit_id')
        if not lawsuit_id:
            return

        try:
            lawsuit = Lawsuit.objects.get(pk=lawsuit_id)
        except Lawsuit.DoesNotExist:
            logger.warning('Lawsuit %s not found for attachment event', lawsuit_id)
            return

        attachment_id = payload.get('attachment_id')
        already_exists = CaseFileItem.objects.filter(
            lawsuit=lawsuit,
            related_object_id=attachment_id,
            related_object_type='attachment',
        ).exists()

        if not already_exists:
            CaseFileItem.objects.create(
                lawsuit=lawsuit,
                item_type=CaseFileItem.TYPE_DOCUMENT,
                title=payload.get('original_filename') or f'مرفق #{attachment_id}',
                description='',
                original_filename=payload.get('original_filename', ''),
                file_size=payload.get('file_size'),
                related_object_id=attachment_id,
                related_object_type='attachment',
                sort_order=50,
            )
            logger.info('CaseFileItem created for attachment %s', attachment_id)
    except Exception as e:
        logger.error('Error handling attachment.created event: %s', e)


def start_event_listeners():
    """Start Redis event listeners for the cases-service."""
    listener = EventListener()
    listener.subscribe('hearings', _handle_hearings_event)
    listener.subscribe('documents', _handle_documents_event)
    listener.listen(daemon=True)
    logger.info('cases-service event listeners started')
