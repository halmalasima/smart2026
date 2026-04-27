import sys

def main():
    filepath = r'd:\smart2026\lib\screens\archive_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # replace isDark with context.isDark in our ternary blocks
    content = content.replace('(isDark ?', '(context.isDark ?')
    
    # inject the app_theme import if missing
    import_appcolors = "import '../theme/app_colors.dart';"
    import_apptheme = "import '../theme/app_theme.dart';"
    
    if import_apptheme not in content:
        content = content.replace(import_appcolors, f"{import_appcolors}\n{import_apptheme}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
