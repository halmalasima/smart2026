import os
import re

directories = [r'd:\smart2026\lib\screens', r'd:\smart2026\lib\widgets']

replaced_files = 0

for directory in directories:
    if not os.path.exists(directory): continue
    for root, _, files in os.walk(directory):
        for file in files:
            if not file.endswith('.dart'): continue
            if file == 'login_screen.dart': continue
            
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original = content
            
            # Simple replacements for light mode fixed backgrounds
            content = content.replace('Color(0xFFF7F8FA)', '(context.isDark ? AppColors.darkBackground : AppColors.lightBackground)')
            content = content.replace('Color(0xFFFFFFFF)', '(context.isDark ? AppColors.darkSurface : AppColors.lightSurface)')
            
            # Additional UI fixes
            content = re.sub(r'backgroundColor:\s*Colors\.white\b', 'backgroundColor: context.isDark ? AppColors.darkSurface : AppColors.lightSurface', content)
            content = re.sub(r'backgroundColor:\s*AppColors\.lightBackground\b', 'backgroundColor: context.isDark ? AppColors.darkBackground : AppColors.lightBackground', content)
            content = re.sub(r'color:\s*AppColors\.lightSurface\b', 'color: context.isDark ? AppColors.darkSurface : AppColors.lightSurface', content)
            
            if content != original:
                # Add Theme import if context.isDark was injected and not present
                if 'context.isDark' in content and 'app_theme.dart' not in content:
                    content = content.replace("import '../theme/app_colors.dart';", "import '../theme/app_colors.dart';\nimport '../theme/app_theme.dart';")
                    content = content.replace("import '../../theme/app_colors.dart';", "import '../../theme/app_colors.dart';\nimport '../../theme/app_theme.dart';")
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                replaced_files += 1
                print(f'Fixed {file}')

print(f'Done fixing {replaced_files} files.')
