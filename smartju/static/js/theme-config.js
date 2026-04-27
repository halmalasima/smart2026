/**
 * SmartJudi Theme Configuration
 * =============================
 * Tailwind configuration matching Flutter theme
 */

const smartjudiTheme = {
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                /* Brand Colors - Matching Flutter AppColors */
                brand: {
                    DEFAULT: '#1B5E3B',
                    light: '#2D8B57',
                    dark: '#0D3B23',
                },
                gold: {
                    DEFAULT: '#D4A940',
                    light: '#E8C667',
                    dark: '#B08C2A',
                },
                
                /* Semantic Colors */
                success: {
                    DEFAULT: '#22C55E',
                    bg: 'rgba(34, 197, 94, 0.1)',
                },
                warning: {
                    DEFAULT: '#F59E0B',
                    bg: 'rgba(245, 158, 11, 0.1)',
                },
                error: {
                    DEFAULT: '#EF4444',
                    bg: 'rgba(239, 68, 68, 0.1)',
                },
                info: {
                    DEFAULT: '#3B82F6',
                    bg: 'rgba(59, 130, 246, 0.1)',
                },
                
                /* Service Colors - Matching Flutter */
                coral: '#F43F5E',
                ocean: '#0EA5E9',
                violet: '#8B5CF6',
                amber: '#F59E0B',
                teal: '#14B8A6',
                rose: '#EC4899',
                indigo: '#6366F1',
                emerald: '#10B981',
                
                /* shadcn/ui compatible variables */
                border: 'hsl(var(--border))',
                input: 'hsl(var(--input))',
                ring: 'hsl(var(--ring))',
                background: 'hsl(var(--background))',
                foreground: 'hsl(var(--foreground))',
                primary: {
                    DEFAULT: 'hsl(var(--primary))',
                    foreground: 'hsl(var(--primary-foreground))',
                },
                secondary: {
                    DEFAULT: 'hsl(var(--secondary))',
                    foreground: 'hsl(var(--secondary-foreground))',
                },
                destructive: {
                    DEFAULT: 'hsl(var(--destructive))',
                    foreground: 'hsl(var(--destructive-foreground))',
                },
                muted: {
                    DEFAULT: 'hsl(var(--muted))',
                    foreground: 'hsl(var(--muted-foreground))',
                },
                accent: {
                    DEFAULT: 'hsl(var(--accent))',
                    foreground: 'hsl(var(--accent-foreground))',
                },
                popover: {
                    DEFAULT: 'hsl(var(--popover))',
                    foreground: 'hsl(var(--popover-foreground))',
                },
                card: {
                    DEFAULT: 'hsl(var(--card))',
                    foreground: 'hsl(var(--card-foreground))',
                },
            },
            borderRadius: {
                lg: 'var(--radius)',
                md: 'calc(var(--radius) - 2px)',
                sm: 'calc(var(--radius) - 4px)',
            },
            fontFamily: {
                sans: ['Cairo', 'system-ui', 'sans-serif'],
                cairo: ['Cairo', 'sans-serif'],
            },
            boxShadow: {
                'sj-sm': '0 2px 4px rgba(0, 0, 0, 0.04)',
                'sj-md': '0 4px 8px rgba(0, 0, 0, 0.06)',
                'sj-lg': '0 8px 16px rgba(0, 0, 0, 0.08)',
                'sj-gold': '0 0 20px rgba(212, 169, 64, 0.4), 0 0 40px rgba(212, 169, 64, 0.1)',
            },
        },
    },
};

// Initialize Tailwind with SmartJudi theme
if (typeof tailwind !== 'undefined') {
    tailwind.config = smartjudiTheme;
}
