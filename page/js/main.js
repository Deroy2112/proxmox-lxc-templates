/* ============================================
   Proxmox LXC Templates - Main JavaScript
   ============================================ */

(function() {
  'use strict';

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
      });

      overlay?.addEventListener('click', () => {
        sidebar.classList.remove('open');
        overlay.classList.remove('open');
      });
    }
  };

  // === Search ===
  const Search = {
    init() {
      const input = document.querySelector('.search-input');
      if (!input) return;

      input.addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase().trim();
        this.filterTemplates(query);
      });
    },

    filterTemplates(query) {
      const cards = document.querySelectorAll('.template-card');
      let visibleCount = 0;

      cards.forEach(card => {
        const name = card.dataset.name?.toLowerCase() || '';
        const description = card.dataset.description?.toLowerCase() || '';
        const category = card.dataset.category?.toLowerCase() || '';

        const matches = !query ||
          name.includes(query) ||
          description.includes(query) ||
          category.includes(query);

        card.style.display = matches ? '' : 'none';
        if (matches) visibleCount++;
      });

      // Show/hide no results message
      const noResults = document.querySelector('.no-results');
      if (noResults) {
        noResults.style.display = visibleCount === 0 ? 'block' : 'none';
      }
    }
  };

  // === Category Filter ===
  const CategoryFilter = {
    init() {
      const navItems = document.querySelectorAll('.nav-item[data-category]');

      navItems.forEach(item => {
        item.addEventListener('click', () => {
          const category = item.dataset.category;
          this.filter(category);
          this.updateActive(item);
        });
      });
    },

    filter(category) {
      const cards = document.querySelectorAll('.template-card');

      cards.forEach(card => {
        if (category === 'all' || card.dataset.category === category) {
          card.style.display = '';
        } else {
          card.style.display = 'none';
        }
      });

      // Clear search when filtering
      const searchInput = document.querySelector('.search-input');
      if (searchInput) searchInput.value = '';
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
            console.error('Failed to copy:', err);
          }
        });
      });
    },

    showCopied(btn) {
      btn.classList.add('copied');
      const originalHTML = btn.innerHTML;
      btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`;

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

          // Close all others (optional: remove for multi-open)
          document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));

          // Toggle current
          if (!wasOpen) {
            item.classList.add('open');
          }
        });
      });
    }
  };

  // === Template Loader (for index page) ===
  const TemplateLoader = {
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
      } catch (err) {
        console.error('Error loading templates:', err);
        grid.innerHTML = '<p class="text-muted">Failed to load templates.</p>';
      }
    },

    render(container, templates) {
      container.innerHTML = templates.map(t => this.createCard(t)).join('');
    },

    createCard(template) {
      const iconUrl = template.icon
        ? `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/svg/${template.icon}.svg`
        : '';

      return `
        <a href="templates/${template.name}.html" class="template-card"
           data-name="${template.name}"
           data-description="${template.description}"
           data-category="${template.category}">
          <div class="template-card-header">
            <div class="template-icon ${template.category}">
              ${iconUrl ? `<img src="${iconUrl}" alt="${template.name}" onerror="this.style.display='none'">` : ''}
            </div>
            <div class="template-info">
              <div class="template-name">${template.name}</div>
              <span class="template-version">${template.version}</span>
            </div>
          </div>
          <p class="template-description">${template.description}</p>
          <div class="template-meta">
            <span class="template-meta-item">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
              ${template.os}
            </span>
            <span class="template-meta-item">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>
              ${template.resources?.memory_recommended || 512} MB
            </span>
          </div>
        </a>
      `;
    },

    updateCounts(templates) {
      const counts = { all: templates.length };
      templates.forEach(t => {
        counts[t.category] = (counts[t.category] || 0) + 1;
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

  // === Initialize ===
  function init() {
    ThemeManager.init();
    MobileMenu.init();
    Search.init();
    CategoryFilter.init();
    CopyButton.init();
    FAQ.init();
    TemplateLoader.init();
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
