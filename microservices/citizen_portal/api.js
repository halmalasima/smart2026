/**
 * API Wrapper for SmartJudi Microservices
 * Uses relative paths to work behind the same gateway
 */
const API_BASE = '/api';

const api = {
    async get(endpoint) {
        try {
            const response = await fetch(`${API_BASE}${endpoint}`, {
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('token')}`,
                    'Content-Type': 'application/json'
                }
            });
            if (response.status === 401) {
                return null;
            }
            return await response.json();
        } catch (error) {
            console.error('API Error:', error);
            return null;
        }
    },

    async publicGet(endpoint) {
        try {
            console.log(`Fetching: ${API_BASE}${endpoint}`);
            const response = await fetch(`${API_BASE}${endpoint}`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            console.log(`Received data for ${endpoint}:`, data);
            return data;
        } catch (error) {
            console.error('Public API Error:', error);
            return { error: error.message };
        }
    }
};

const ENDPOINTS = {
    LAWS: '/law-library-books/',
    LAW_CATEGORIES: '/law-library-books/categories/',
    LAWYERS: '/lawyers/',
    LAWYER_FILTERS: '/lawyer-filters/',
    PROFILE: '/auth/users/me/',
};
