// =============================================
// SUPABASE CLIENT - Conecta RH
// =============================================

const SUPABASE_URL = 'https://tromwamwgunruypxmccu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyb213YW13Z3VucnV5cHhtY2N1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNzkzOTksImV4cCI6MjEwMzk1NTM5OX0.Sv8xKrbTYPunnUSM7_2oLjjAFEebRajmEIs52YRd6mY';

const _sc = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const db = {
  async getJobs(filters = {}) {
    let query = _sc.from('jobs').select('*, companies(name, slug, logo_url, industry)');
    if (filters.status) query = query.eq('status', filters.status);
    if (filters.area) query = query.eq('area', filters.area);
    if (filters.modality) query = query.eq('modality', filters.modality);
    if (filters.location) query = query.ilike('location', `%${filters.location}%`);
    if (filters.search) query = query.or(`title.ilike.%${filters.search}%,description.ilike.%${filters.search}%`);
    if (filters.featured) query = query.eq('is_featured', true);
    query = query.order('is_featured', { ascending: false }).order('created_at', { ascending: false });
    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  async getJobById(id) {
    const { data, error } = await _sc.from('jobs').select('*, companies(*)').eq('id', id).single();
    if (error) throw error;
    return data;
  },

  async createCandidate(candidate) {
    const { data, error } = await _sc.from('candidates').upsert(candidate, { onConflict: 'email' }).select().single();
    if (error) throw error;
    return data;
  },

  async createApplication(application) {
    const { data, error } = await _sc.from('job_applications').insert(application).select().single();
    if (error) throw error;
    return data;
  },

  async createRecruitmentRequest(request) {
    const { data, error } = await _sc.from('recruitment_requests').insert(request).select().single();
    if (error) throw error;
    return data;
  },

  async getTestimonials() {
    const { data, error } = await _sc.from('testimonials').select('*').eq('is_active', true).order('created_at', { ascending: false });
    if (error) throw error;
    return data;
  },

  async getFaqItems(category = null) {
    let query = _sc.from('faq_items').select('*').eq('is_active', true).order('sort_order');
    if (category) query = query.eq('category', category);
    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  async login(email, password) {
    const { data, error } = await _sc.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  },

  async logout() {
    const { error } = await _sc.auth.signOut();
    if (error) throw error;
  },

  async getUser() {
    const { data: { user } } = await _sc.auth.getUser();
    return user;
  },

  async register(email, password, fullName) {
    const { data, error } = await _sc.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName } }
    });
    if (error) throw error;
    return data;
  },

  async getUserProfile(userId) {
    const { data, error } = await _sc.from('users').select('*').eq('id', userId).single();
    if (error) {
      const { data: newProfile } = await _sc.from('users').insert({ id: userId, full_name: '', role: 'funcionario', status: 'approved' }).select().single();
      return newProfile;
    }
    return data;
  },

  async uploadResume(file, candidateId) {
    const fileExt = file.name.split('.').pop();
    const fileName = `${candidateId}/${Date.now()}.${fileExt}`;
    const { data, error } = await _sc.storage.from('resumes').upload(fileName, file);
    if (error) throw error;
    return data.path;
  },

  async getCompanies() {
    const { data, error } = await _sc.from('companies').select('*').order('name');
    if (error) throw error;
    return data;
  },

  async getStats() {
    const [jobs, applications, companies, testimonials] = await Promise.all([
      _sc.from('jobs').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      _sc.from('job_applications').select('*', { count: 'exact', head: true }),
      _sc.from('companies').select('*', { count: 'exact', head: true }),
      _sc.from('testimonials').select('*', { count: 'exact', head: true }).eq('is_active', true)
    ]);
    return {
      jobs: jobs.count || 0,
      applications: applications.count || 0,
      companies: companies.count || 0,
      testimonials: testimonials.count || 0
    };
  }
};
