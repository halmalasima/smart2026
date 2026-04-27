import os
import re

directories = [r'd:\smart2026\lib\screens', r'd:\smart2026\lib\widgets']

for directory in directories:
    if not os.path.exists(directory): continue
    for root, _, files in os.walk(directory):
        for file in files:
            if not file.endswith('.dart'): continue
            
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original = content
            
            # Fix const (context.isDark ...)
            content = content.replace('const (context.isDark', '(context.isDark')
            
            # Ensure imports if context.isDark or AppColors is used
            if 'context.isDark' in content or 'AppColors' in content:
                # determine path depth
                depth = filepath.replace(r'd:\smart2026\lib\\', '').count('\\')
                prefix = '../' * depth
                if depth == 0:
                    prefix = './'
                
                app_colors_import = f"import '{prefix}theme/app_colors.dart';"
                app_theme_import = f"import '{prefix}theme/app_theme.dart';"
                
                if 'app_colors.dart' not in content:
                    content = app_colors_import + '\n' + content
                if 'app_theme.dart' not in content:
                    content = app_theme_import + '\n' + content
                
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f'Fixed {file}')
