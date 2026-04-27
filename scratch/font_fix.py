import re

filepath = r'd:\smart2026\lib\screens\legal_library_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove fontFamily: 'Cairo' entirely.
content = re.sub(r",\s*fontFamily:\s*'Cairo'", '', content)
content = re.sub(r"fontFamily:\s*'Cairo',\s*", '', content)
content = re.sub(r"fontFamily:\s*'Cairo'", '', content)

# Modernize card styling manually
content = content.replace('''                article['source_title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF424242),
                ),''', '''                article['source_title'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF2C3E50),
                ),''')

content = content.replace('''                style: TextStyle(color: Colors.grey[700], height: 1.5),''', '''                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey[700], height: 1.6, fontSize: 13),''')

content = content.replace('''              if (article['chapter_title'] != null && article['chapter_title'].toString().isNotEmpty)
                Text(
                  article['chapter_title'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),''', '''              if (article['chapter_title'] != null && article['chapter_title'].toString().isNotEmpty)
                Text(
                  article['chapter_title'],
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : Colors.grey[600]),
                ),''')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed fonts and card styles.')
