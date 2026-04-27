import os
import re

directories = [r'd:\smart2026\lib\screens', r'd:\smart2026\lib\widgets']
files_changed = 0

for directory in directories:
    if not os.path.exists(directory): continue
    for root, _, files in os.walk(directory):
        for file in files:
            if not file.endswith('.dart'): continue
            
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original = content
            
            # The app should be Dark Green (brand), not gold.
            content = content.replace('AppColors.goldDark', 'AppColors.brandDark')
            content = content.replace('AppColors.goldLight', 'AppColors.brandLight')
            content = content.replace('AppColors.gold', 'AppColors.brand')
            
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f'Fixed {file}')
                files_changed += 1

print(f'Done replacing gold with brand green in {files_changed} files.')
