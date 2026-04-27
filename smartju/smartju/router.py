class MicroserviceRouter:
    """
    A router to control all database operations on models in the
    different microservice-linked applications.
    """
    
    # Map of app_label to database alias
    APP_MAP = {
        # Auth & Accounts
        'accounts': 'auth_db',
        'auth': 'auth_db',
        'sessions': 'auth_db',
        'contenttypes': 'auth_db',
        
        # Cases & Lawsuits
        'lawsuits': 'cases_db',
        'parties': 'cases_db',
        'responses': 'cases_db',
        'appeals': 'cases_db',
        'judgments': 'cases_db',
        'payments': 'cases_db',
        
        # Hearings
        'hearings': 'hearings_db',
        
        # Legal
        'laws': 'legal_db',
        'courts': 'legal_db',
        'lawyers': 'legal_db',
        
        # Documents
        'attachments': 'documents_db',
        
        # Notifications & Messaging
        'notifications': 'notifications_db',
        'messaging': 'notifications_db',
        
        # Search & Logs
        'logs': 'search_db',
        'audit': 'search_db',
    }

    def db_for_read(self, model, **hints):
        return self.APP_MAP.get(model._meta.app_label, 'default')

    def db_for_write(self, model, **hints):
        return self.APP_MAP.get(model._meta.app_label, 'default')

    def allow_relation(self, obj1, obj2, **hints):
        # Allow relations if both objects are in the same DB or one is in 'default'
        db1 = self.APP_MAP.get(obj1._meta.app_label, 'default')
        db2 = self.APP_MAP.get(obj2._meta.app_label, 'default')
        if db1 == db2:
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        target_db = self.APP_MAP.get(app_label, 'default')
        return db == target_db
