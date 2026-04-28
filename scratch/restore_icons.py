import re
import os

mapping = {
    'fa-moon': 'ti-moon', 'fa-sun': 'ti-sun', 'fa-arrow-left': 'ti-arrow-left', 'fa-arrow-right': 'ti-arrow-right',
    'fa-rocket': 'ti-rocket', 'fa-compass': 'ti-compass', 'fa-shield-halved': 'ti-shield', 'fa-bolt': 'ti-bolt',
    'fa-mobile-screen': 'ti-device-mobile', 'fa-language': 'ti-language', 'fa-wand-magic-sparkles': 'ti-wand',
    'fa-gavel': 'ti-gavel', 'fa-file-contract': 'ti-file-certificate', 'fa-bell': 'ti-bell',
    'fa-layer-group': 'ti-layers-intersect', 'fa-clock': 'ti-clock', 'fa-scale-balanced': 'ti-scale',
    'fa-magnifying-glass-chart': 'ti-search', 'fa-calendar-check': 'ti-calendar-check', 'fa-users': 'ti-users',
    'fa-balance-scale': 'ti-scale', 'fa-building': 'ti-building-bank', 'fa-book': 'ti-book',
    'fa-comments': 'ti-messages', 'fa-headset': 'ti-headset', 'fa-shield-check': 'ti-shield-check',
    'fa-lock': 'ti-lock', 'fa-eye-slash': 'ti-eye-off', 'fa-eye': 'ti-eye', 'fa-id-card': 'ti-id',
    'fa-at': 'ti-at', 'fa-envelope': 'ti-mail', 'fa-stamp': 'ti-stamp', 'fa-plus-circle': 'ti-circle-plus',
    'fa-calendar-day': 'ti-calendar-event', 'fa-chart-line': 'ti-chart-line', 'fa-user-clock': 'ti-history',
    'fa-check-circle': 'ti-circle-check', 'fa-user-slash': 'ti-user-off', 'fa-chevron-left': 'ti-chevron-left',
    'fa-map-marker-alt': 'ti-map-pin', 'fa-folder-open': 'ti-folder-open', 'fa-shield-alt': 'ti-shield-check',
    'fa-bars': 'ti-menu-2', 'fa-search': 'ti-search', 'fa-sign-out-alt': 'ti-logout', 'fa-chart-pie': 'ti-chart-pie',
    'fa-users-cog': 'ti-users-group', 'fa-landmark': 'ti-building-bank', 'fa-sliders-h': 'ti-adjustments',
    'fa-user-plus': 'ti-user-plus', 'fa-folder-plus': 'ti-folder-plus', 'fa-robot': 'ti-robot',
    'fa-credit-card': 'ti-credit-card', 'fa-circle-exclamation': 'ti-alert-circle', 'fa-circle-check': 'ti-circle-check',
    'fa-trash': 'ti-trash', 'fa-edit': 'ti-edit', 'fa-plus': 'ti-plus', 'fa-diamond': 'ti-diamond',
    'fa-star': 'ti-star', 'fa-gift': 'ti-gift', 'fa-crown': 'ti-crown', 'fa-circle-x': 'ti-circle-x',
    'fa-infinity': 'ti-infinity', 'fa-circle-dot': 'ti-circle-dot', 'fa-diamond-off': 'ti-diamond-off',
    'fa-scale-outline': 'ti-scale-outline'
}

def convert_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        original_content = f.read()
    
    # Fix CDN link if present
    content = original_content.replace(
        'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.3.0/tabler-icons.min.css',
        'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.3.0/dist/tabler-icons.min.css'
    )
    
    # Convert icons
    new_content = re.sub(
        r'(fas|far|fab|fa) fa-([a-z0-9-]+)',
        lambda m: 'ti ' + mapping.get('fa-' + m.group(2), 'ti-' + m.group(2)),
        content
    )
    
    if new_content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

dirs_to_process = [
    'd:/smart2026/smartju/control_panel/templates/control_panel',
    'd:/smart2026/smartju/dashboard/templates/dashboard'
]

for d in dirs_to_process:
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith('.html'):
                convert_file(os.path.join(root, f))
