import os
import ast

def get_models(base_dir):
    models = {}
    for dirpath, _, filenames in os.walk(base_dir):
        if 'models.py' in filenames:
            path = os.path.join(dirpath, 'models.py')
            try:
                code = open(path, 'r', encoding='utf-8').read()
                classes = [node.name for node in ast.walk(ast.parse(code)) if isinstance(node, ast.ClassDef) and 'Meta' not in node.name]
                if classes:
                    rel_path = os.path.relpath(path, base_dir)
                    models[rel_path] = classes
            except Exception as e:
                pass
    return models

print('--- MONOLITH MODELS ---')
for k, v in get_models(r'f:\smart2026\smartju').items():
    print(f'{k}: {v}')

print('\n--- MICROSERVICES MODELS ---')
for k, v in get_models(r'f:\smart2026\microservices\services').items():
    print(f'{k}: {v}')
