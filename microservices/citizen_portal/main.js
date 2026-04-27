/**
 * Citizen Portal Main Logic
 * Handles view switching, data fetching, and UI rendering
 */

document.addEventListener('DOMContentLoaded', () => {
    initApp();
});

function initApp() {
    // Navigation setup
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const view = item.getAttribute('data-view');
            if (view) switchView(view);
            
            // Update active state
            navItems.forEach(n => n.classList.remove('active'));
            item.classList.add('active');
        });
    });

    // Theme toggle
    const themeBtn = document.getElementById('theme-toggle');
    themeBtn.addEventListener('click', () => {
        document.body.classList.toggle('light-theme');
        document.body.classList.toggle('dark-theme');
        const icon = themeBtn.querySelector('i');
        icon.classList.toggle('fa-moon');
        icon.classList.toggle('fa-sun');
    });

    // Global Search
    const globalSearch = document.getElementById('global-search');
    globalSearch.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            const query = globalSearch.value.trim();
            if (query) {
                switchView('library', query);
            }
        }
    });

    // Initial View
    switchView('library');
}

async function switchView(view, query = null) {
    const area = document.getElementById('content-area');
    area.innerHTML = '<div class="loader-container"><div class="loader"></div></div>';

    switch (view) {
        case 'library':
            await renderLibrary(query);
            break;
        case 'lawyers':
            await renderLawyers(query);
            break;
        case 'services':
            renderServices();
            break;
        case 'profile':
            await renderProfile();
            break;
        default:
            area.innerHTML = '<h1>View Not Found</h1>';
    }
}

// --- View Renderers ---

async function renderLibrary(query = null) {
    console.log('Rendering Library...');
    const endpoint = query ? `${ENDPOINTS.LAWS}?q=${encodeURIComponent(query)}` : ENDPOINTS.LAWS;
    const data = await api.publicGet(endpoint);
    const catData = await api.publicGet(ENDPOINTS.LAW_CATEGORIES);
    
    if (data?.error) {
        showError('تعذر تحميل المكتبة القانونية: ' + data.error);
        return;
    }

    const results = data.results || [];
    const categories = catData.categories || [];

    let html = `
        <div class="view-header">
            <h1>المكتبة القانونية الشاملة</h1>
            <p>${query ? `نتائج البحث عن: "${query}"` : 'تصفح وتحميل التشريعات والقوانين والمراجع اليمنية المحدثة'}</p>
        </div>
        
        <div class="filter-bar">
            <button class="filter-chip ${!query ? 'active' : ''}">الكل</button>
            ${categories.slice(0, 8).map(c => `<button class="filter-chip">${c.category}</button>`).join('')}
        </div>

        <div class="grid-cards">
            ${results.length > 0 ? results.map(item => `
                <div class="card library-card">
                    <div class="card-icon">
                        <i class="fas fa-book"></i>
                    </div>
                    <div class="card-content">
                        <span class="badge">${item.category || 'عام'}</span>
                        <h3>${item.title}</h3>
                        <p>${item.description || 'لا يوجد وصف متاح لهذا المرجع.'}</p>
                        <div class="card-footer">
                            ${item.pdf_url ? `<a href="${item.pdf_url}" target="_blank" class="btn btn-outline btn-sm"><i class="fas fa-download"></i> تحميل</a>` : ''}
                            <button class="btn btn-primary btn-sm">تصفح</button>
                        </div>
                    </div>
                </div>
            `).join('') : '<div class="empty-state">لا توجد كتب متاحة حالياً</div>'}
        </div>
    `;
    document.getElementById('content-area').innerHTML = html;
}

async function renderLawyers(query = null) {
    const endpoint = query ? `${ENDPOINTS.LAWYERS}?search=${encodeURIComponent(query)}` : ENDPOINTS.LAWYERS;
    const data = await api.publicGet(endpoint);
    
    if (data?.error) {
        showError('تعذر تحميل قائمة المحامين: ' + data.error);
        return;
    }

    const lawyers = data.results || [];

    let html = `
        <div class="view-header">
            <h1>البحث عن محامي</h1>
            <p>${query ? `نتائج البحث عن: "${query}"` : 'ابحث عن أفضل المحامين المعتمدين في اليمن حسب التخصص والمنطقة'}</p>
        </div>

        <div class="search-box-large">
            <input type="text" placeholder="ابحث باسم المحامي أو التخصص أو المدينة..." id="lawyer-search-input" value="${query || ''}">
            <button class="btn btn-primary" onclick="switchView('lawyers', document.getElementById('lawyer-search-input').value)"><i class="fas fa-search"></i> بحث</button>
        </div>

        <div class="grid-cards">
            ${lawyers.length > 0 ? lawyers.map(l => `
                <div class="card lawyer-card">
                    <div class="lawyer-header">
                        <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(l.name)}&background=6366f1&color=fff" class="lawyer-avatar">
                        <div class="lawyer-info">
                            <h3>${l.name}</h3>
                            <span class="specialization">${l.specialization || 'محامي عام'}</span>
                        </div>
                    </div>
                    <div class="lawyer-body">
                        <div class="info-item"><i class="fas fa-map-marker-alt"></i> ${l.office_address || l.city || 'اليمن'}</div>
                        <div class="info-item"><i class="fas fa-briefcase"></i> خبرة ${l.years_of_experience || '5+'} سنوات</div>
                        <div class="rating">
                            <i class="fas fa-star"></i>
                            <i class="fas fa-star"></i>
                            <i class="fas fa-star"></i>
                            <i class="fas fa-star"></i>
                            <i class="fas fa-star-half-alt"></i>
                            <span>4.8</span>
                        </div>
                    </div>
                    <div class="lawyer-footer">
                        <button class="btn btn-outline full-width">عرض الملف الشخصي</button>
                        <button class="btn btn-primary full-width">تواصل الآن</button>
                    </div>
                </div>
            `).join('') : '<div class="empty-state">لا يوجد محامون متاحون حالياً</div>'}
        </div>
    `;
    document.getElementById('content-area').innerHTML = html;
}

function renderServices() {
    const services = [
        { title: 'دليل الإجراءات القانونية', icon: 'fa-clipboard-list', desc: 'دليل شامل لخطوات التقاضي والمعاملات الرسمية.' },
        { title: 'حساب الميراث الشرعي', icon: 'fa-calculator', desc: 'أداة ذكية لحساب المواريث حسب الشريعة الإسلامية والقانون اليمني.' },
        { title: 'نماذج وصيغ قانونية', icon: 'fa-file-signature', desc: 'تحميل نماذج العقود والعرائض والمذكرات القانونية الجاهزة.' },
        { title: 'الاستعلام عن قضية', icon: 'fa-search-plus', desc: 'خدمة استرشادية لمتابعة حالة القضايا في المحاكم.' },
    ];

    let html = `
        <div class="view-header">
            <h1>الخدمات العامة</h1>
            <p>أدوات وخدمات قانونية مجانية لخدمة المواطن</p>
        </div>
        <div class="grid-cards">
            ${services.map(s => `
                <div class="card service-card">
                    <i class="fas ${s.icon} service-icon"></i>
                    <h3>${s.title}</h3>
                    <p>${s.desc}</p>
                    <button class="btn btn-outline">فتح الخدمة</button>
                </div>
            `).join('')}
        </div>
    `;
    document.getElementById('content-area').innerHTML = html;
}

async function renderProfile() {
    // Attempt to get profile data (requires login)
    const user = await api.get(ENDPOINTS.PROFILE);
    
    let html = `
        <div class="view-header">
            <h1>الملف الشخصي</h1>
        </div>
        <div class="profile-container">
            ${user ? `
                <div class="card profile-card">
                    <div class="profile-header">
                        <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(user.name)}&background=6366f1&color=fff&size=128" class="large-avatar">
                        <h2>${user.name}</h2>
                        <p>${user.phone || ''}</p>
                    </div>
                    <div class="profile-details">
                        <div class="detail-row"><span>البريد الإلكتروني:</span> <span>${user.email || 'غير مسجل'}</span></div>
                        <div class="detail-row"><span>نوع الحساب:</span> <span>${user.user_type === 'CITIZEN' ? 'مواطن' : 'محامي'}</span></div>
                        <div class="detail-row"><span>تاريخ الانضمام:</span> <span>${new Date(user.date_joined).toLocaleDateString('ar-YE')}</span></div>
                    </div>
                    <button class="btn btn-primary">تعديل البيانات</button>
                </div>
            ` : `
                <div class="card login-prompt">
                    <i class="fas fa-user-lock"></i>
                    <h2>سجل دخولك للوصول للملف الشخصي</h2>
                    <p>يمكنك حفظ مفضلاتك ومتابعة خدماتك الخاصة عند تسجيل الدخول.</p>
                    <div style="display: flex; gap: 1rem; margin-top: 2rem;">
                        <button class="btn btn-primary">تسجيل الدخول</button>
                        <button class="btn btn-outline">إنشاء حساب جديد</button>
                    </div>
                </div>
            `}
        </div>
    `;
    document.getElementById('content-area').innerHTML = html;
}

function showError(msg) {
    document.getElementById('content-area').innerHTML = `
        <div class="error-container">
            <i class="fas fa-exclamation-circle"></i>
            <h3>حدث خطأ</h3>
            <p>${msg}</p>
            <button onclick="initApp()" class="btn btn-primary">إعادة المحاولة</button>
        </div>
    `;
}
