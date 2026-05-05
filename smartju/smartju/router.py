from control_panel.services import MICROSERVICE_REGISTRY

class MicroserviceRouter:
    """
    A router to control all database operations on models in the
    different microservice-linked applications.
    """
    
    # Map of app_label to database alias dynamically from registry
    APP_MAP = {}

    def __init__(self):
        # Generate APP_MAP dynamically
        # Map Django default apps
        self.APP_MAP = {
            'auth': 'auth_db',
            'sessions': 'auth_db',
            'contenttypes': 'auth_db',
            'dashboard': 'auth_db',
            'control_panel': 'auth_db',
            'token_blacklist': 'auth_db',
            'logs': 'auth_db',
        }
        
        for svc_key, svc_data in MICROSERVICE_REGISTRY.items():
            for app in svc_data.get('apps', []):
                self.APP_MAP[app] = svc_data.get('db', 'default')

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
        
        # Allow cross-database logical relations between any microservice and auth_db 
        # (Needed to assign User to Lawsuits, Hearings, etc. without ValueError)
        if db1 == 'auth_db' or db2 == 'auth_db':
            return True
            
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        target_db = self.APP_MAP.get(app_label, 'default')
        return db == target_db
