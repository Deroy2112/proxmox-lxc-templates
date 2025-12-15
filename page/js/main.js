/* ============================================
   Proxmox LXC Templates - Main JavaScript
   Umbrel-inspired Design System
   ============================================ */

(function() {
  'use strict';

  // === Utilities ===
  const Utils = {
    // HTML escape to prevent XSS
    escapeHtml(str) {
      if (!str) return '';
      const div = document.createElement('div');
      div.textContent = str;
      return div.innerHTML;
    },

    // Debounce function
    debounce(fn, delay) {
      let timeoutId;
      return function(...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => fn.apply(this, args), delay);
      };
    },

    // Parse URL params
    getUrlParam(name) {
      const params = new URLSearchParams(window.location.search);
      return params.get(name);
    }
  };

  // === Theme Management ===
  const ThemeManager = {
    STORAGE_KEY: 'theme',
    THEMES: ['light', 'dark', 'system'],

    init() {
      const saved = localStorage.getItem(this.STORAGE_KEY) || 'system';
      this.apply(saved);
      this.updateButtons(saved);
      this.bindEvents();

      // Listen for system theme changes
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (localStorage.getItem(this.STORAGE_KEY) === 'system') {
          this.apply('system');
        }
      });
    },

    apply(theme) {
      let effectiveTheme = theme;
      if (theme === 'system') {
        effectiveTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
      document.documentElement.setAttribute('data-theme', effectiveTheme);
    },

    set(theme) {
      localStorage.setItem(this.STORAGE_KEY, theme);
      this.apply(theme);
      this.updateButtons(theme);
    },

    updateButtons(activeTheme) {
      document.querySelectorAll('.theme-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.theme === activeTheme);
      });
    },

    bindEvents() {
      document.querySelectorAll('.theme-btn').forEach(btn => {
        btn.addEventListener('click', () => this.set(btn.dataset.theme));
      });
    }
  };

  // === Mobile Menu ===
  const MobileMenu = {
    init() {
      const toggle = document.querySelector('.mobile-menu-toggle');
      const sidebar = document.querySelector('.sidebar');
      const overlay = document.querySelector('.sidebar-overlay');

      if (!toggle || !sidebar) return;

      toggle.addEventListener('click', () => {
        sidebar.classList.toggle('open');
        overlay?.classList.toggle('open');
        document.body.classList.toggle('sidebar-open');
      });

      overlay?.addEventListener('click', () => {
        sidebar.classList.remove('open');
        overlay.classList.remove('open');
        document.body.classList.remove('sidebar-open');
      });

      // Close on escape
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && sidebar.classList.contains('open')) {
          sidebar.classList.remove('open');
          overlay?.classList.remove('open');
          document.body.classList.remove('sidebar-open');
        }
      });
    }
  };

  // === Search & Filter ===
  const SearchFilter = {
    currentCategory: 'all',
    currentQuery: '',

    init() {
      const input = document.querySelector('.search-input');
      if (!input) return;

      // Debounced search
      const debouncedFilter = Utils.debounce(() => {
        this.currentQuery = input.value.toLowerCase().trim();
        this.applyFilters();
      }, 150);

      input.addEventListener('input', debouncedFilter);

      // Check for URL param
      const queryParam = Utils.getUrlParam('q');
      if (queryParam) {
        input.value = queryParam;
        this.currentQuery = queryParam.toLowerCase().trim();
      }
    },

    setCategory(category) {
      this.currentCategory = category;
      this.applyFilters();

      // Clear search when switching categories (optional)
      // const searchInput = document.querySelector('.search-input');
      // if (searchInput) searchInput.value = '';
      // this.currentQuery = '';
    },

    applyFilters() {
      const cards = document.querySelectorAll('.template-card');
      let visibleCount = 0;

      cards.forEach(card => {
        const name = (card.dataset.name || '').toLowerCase();
        const description = (card.dataset.description || '').toLowerCase();
        const category = card.dataset.category || '';

        const matchesCategory = this.currentCategory === 'all' || category === this.currentCategory;
        const matchesSearch = !this.currentQuery ||
          name.includes(this.currentQuery) ||
          description.includes(this.currentQuery) ||
          category.includes(this.currentQuery);

        const isVisible = matchesCategory && matchesSearch;
        card.style.display = isVisible ? '' : 'none';

        if (isVisible) {
          visibleCount++;
          // Reset animation for visible cards
          card.style.animation = 'none';
          card.offsetHeight; // Trigger reflow
          card.style.animation = '';
        }
      });

      // Show/hide no results message
      const noResults = document.querySelector('.no-results');
      if (noResults) {
        noResults.classList.toggle('hidden', visibleCount > 0);
      }
    }
  };

  // === Category Filter ===
  const CategoryFilter = {
    init() {
      const navItems = document.querySelectorAll('.nav-item[data-category]');

      navItems.forEach(item => {
        item.addEventListener('click', (e) => {
          e.preventDefault();
          const category = item.dataset.category;
          SearchFilter.setCategory(category);
          this.updateActive(item);
        });
      });
    },

    updateActive(activeItem) {
      document.querySelectorAll('.nav-item[data-category]').forEach(item => {
        item.classList.toggle('active', item === activeItem);
      });
    }
  };

  // === Copy to Clipboard ===
  const CopyButton = {
    init() {
      document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const target = btn.dataset.target;
          const text = target
            ? document.querySelector(target)?.textContent
            : btn.closest('.code-block')?.querySelector('code')?.textContent;

          if (!text) return;

          try {
            await navigator.clipboard.writeText(text.trim());
            this.showCopied(btn);
          } catch (err) {
            // Fallback for older browsers
            this.fallbackCopy(text.trim());
            this.showCopied(btn);
          }
        });
      });
    },

    fallbackCopy(text) {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
    },

    showCopied(btn) {
      btn.classList.add('copied');
      const originalHTML = btn.innerHTML;
      btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`;

      setTimeout(() => {
        btn.classList.remove('copied');
        btn.innerHTML = originalHTML;
      }, 2000);
    }
  };

  // === FAQ Accordion ===
  const FAQ = {
    init() {
      document.querySelectorAll('.faq-question').forEach(btn => {
        btn.addEventListener('click', () => {
          const item = btn.closest('.faq-item');
          const wasOpen = item.classList.contains('open');

          // Close all others
          document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));

          // Toggle current
          if (!wasOpen) {
            item.classList.add('open');
          }
        });
      });
    }
  };

  // === Staggered Animations ===
  const Animations = {
    init() {
      // Observe elements with fade-in class
      if (!('IntersectionObserver' in window)) return;

      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
          }
        });
      }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
      });

      document.querySelectorAll('.fade-in').forEach(el => {
        observer.observe(el);
      });
    }
  };

  // === Template Loader (for index page) ===
  const TemplateLoader = {
    // Fallback SVG icon
    FALLBACK_ICON: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path></svg>`,

    async init() {
      const grid = document.querySelector('.template-grid');
      if (!grid || grid.dataset.loaded === 'true') return;

      try {
        const response = await fetch('templates.json');
        if (!response.ok) throw new Error('Failed to load templates');

        const templates = await response.json();
        this.render(grid, templates);
        grid.dataset.loaded = 'true';

        // Update category counts
        this.updateCounts(templates);

        // Initialize search filter after templates are loaded
        SearchFilter.applyFilters();

        // Trigger animations
        Animations.init();
      } catch (err) {
        console.error('Error loading templates:', err);
        grid.innerHTML = '<div class="glass-card" style="padding: var(--space-6); text-align: center;"><p class="text-muted">Failed to load templates. Please try again later.</p></div>';
      }
    },

    render(container, templates) {
      container.innerHTML = templates.map((t, index) => this.createCard(t, index)).join('');
    },

    createCard(template, index) {
      // Escape all user data to prevent XSS
      const name = Utils.escapeHtml(template.name);
      const description = Utils.escapeHtml(template.description);
      const version = Utils.escapeHtml(template.version);
      const os = Utils.escapeHtml(template.os);
      const category = Utils.escapeHtml(template.category);
      const icon = Utils.escapeHtml(template.icon);
      const memory = template.resources?.memory_recommended || 512;

      // Calculate stagger delay (max 0.5s)
      const delay = Math.min(index * 0.05, 0.5);

      const iconUrl = icon
        ? `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/svg/${icon}.svg`
        : '';

      return `
        <a href="templates/${name}.html" class="template-card fade-in"
           data-name="${name}"
           data-description="${description}"
           data-category="${category}"
           style="--delay: ${delay}s">
          <div class="template-card-header">
            <div class="icon-box ${category}">
              ${iconUrl
                ? `<img src="${iconUrl}" alt="${name}" loading="lazy" onerror="this.onerror=null;this.parentElement.innerHTML='${this.FALLBACK_ICON}'">`
                : this.FALLBACK_ICON}
            </div>
            <div class="template-info">
              <div class="template-name">${name}</div>
              <span class="template-version">${version}</span>
            </div>
          </div>
          <p class="template-description">${description}</p>
          <div class="template-meta">
            <span class="template-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
              ${os}
            </span>
            <span class="template-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect><rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect><line x1="6" y1="6" x2="6.01" y2="6"></line><line x1="6" y1="18" x2="6.01" y2="18"></line></svg>
              ${memory} MB
            </span>
          </div>
        </a>
      `;
    },

    updateCounts(templates) {
      const counts = { all: templates.length };
      templates.forEach(t => {
        const cat = t.category || 'other';
        counts[cat] = (counts[cat] || 0) + 1;
      });

      document.querySelectorAll('.nav-item[data-category]').forEach(item => {
        const cat = item.dataset.category;
        const countEl = item.querySelector('.nav-item-count');
        if (countEl && counts[cat] !== undefined) {
          countEl.textContent = counts[cat];
        }
      });
    }
  };

  // === Smooth Scroll ===
  const SmoothScroll = {
    init() {
      document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
          const targetId = anchor.getAttribute('href');
          if (targetId === '#') return;

          const target = document.querySelector(targetId);
          if (target) {
            e.preventDefault();
            target.scrollIntoView({
              behavior: 'smooth',
              block: 'start'
            });

            // Update URL without jumping
            history.pushState(null, '', targetId);
          }
        });
      });
    }
  };

  // === Initialize ===
  function init() {
    ThemeManager.init();
    MobileMenu.init();
    SearchFilter.init();
    CategoryFilter.init();
    CopyButton.init();
    FAQ.init();
    SmoothScroll.init();
    TemplateLoader.init();

    // Initialize animations for non-dynamic content
    requestAnimationFrame(() => {
      Animations.init();
    });
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
