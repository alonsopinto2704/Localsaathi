/**
 * LocalSaathi (लोकल साथी) - Interactive Frontend Engine
 */

(function () {
  'use strict';

  // 1. Data Store & State
  const data = window.LOCAL_SAATHI_DATA || {};
  const { groups = [], categories = [], cities = [], localities = [], i18n = {} } = data;

  const state = {
    cityId: data.defaultCityId || 'mh-mumbai',
    localityId: data.defaultLocalityId || 'mh-mumbai-andheri-west',
    language: localStorage.getItem('ls_lang') || 'en',
    activeTab: 'home',
    savedIds: new Set(JSON.parse(localStorage.getItem('ls_saved') || '[]')),
    searchFilters: {
      query: '',
      localityId: '',
      categoryId: '',
      homeVisits: false,
      openNow: false,
    },
    providers: [...(data.providers || [])],
    activeProfileId: null,
    wizardData: {},
    isProviderPaused: false,
  };

  // Emojis for categories
  const categoryIcons = {
    plumbing: '🔧',
    electrical: '⚡',
    carpentry: '🪚',
    painting: '🎨',
    masonry: '🧱',
    appliance: '❄️',
    lock: '🔑',
    cleaning: '🧹',
    pest: '🦟',
    labour: '👷',
    mechanic: '🛵',
    towing: '🚛',
    medical: '🩺',
    dental: '🦷',
    physio: '🏃',
    diagnostics: '🔬',
    computer: '💻',
    tutor: '📚',
    moving: '📦',
    laundry: '🧺',
    paediatric: '👶',
    network: '📶',
    beauty: '💇',
    tailoring: '🪡',
    security: '🛡️',
    driver: '🚗',
    gardening: '🌱',
    events: '🎉',
    other: '🛠️',
  };

  function getCategoryIcon(key) {
    return categoryIcons[key] || '🛠️';
  }

  // 2. Localization Helpers
  function t(key, fallback = '') {
    const langDict = i18n[state.language] || i18n['en'] || {};
    return langDict[key] || (i18n['en'] && i18n['en'][key]) || fallback || key;
  }

  function applyTranslations() {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (key) {
        el.textContent = t(key, el.textContent);
      }
    });

    const liveSearchInput = document.getElementById('live-search-input');
    if (liveSearchInput) {
      liveSearchInput.placeholder = t('searchPlaceholder');
    }

    const brandDevanagari = document.getElementById('brand-devanagari');
    if (brandDevanagari) {
      brandDevanagari.style.display = state.language === 'en' ? 'inline' : 'none';
    }

    updateLocalityLabels();
  }

  function updateLocalityLabels() {
    const currentLoc = localities.find((l) => l.id === state.localityId);
    const currentCity = cities.find((c) => c.id === state.cityId);
    const locName = currentLoc ? currentLoc.name : 'Andheri West';
    const cityName = currentCity ? currentCity.name : 'Mumbai';

    const headerText = `${locName}, ${cityName}`;
    const headerLocalityEl = document.getElementById('header-locality-name');
    if (headerLocalityEl) headerLocalityEl.textContent = headerText;

    const accountLocEl = document.getElementById('account-current-loc');
    if (accountLocEl) accountLocEl.textContent = headerText;
  }

  // 3. UI Navigation & Tabs
  function selectTab(tabName) {
    state.activeTab = tabName;

    // Update bottom nav
    document.querySelectorAll('.nav-item').forEach((item) => {
      item.classList.toggle('active', item.getAttribute('data-tab') === tabName);
    });

    // Update screen visibility
    document.querySelectorAll('.app-screen-content').forEach((screen) => {
      screen.classList.toggle('active', screen.id === `screen-${tabName}`);
    });

    // Toggle home-search-trigger in header
    const searchTrigger = document.getElementById('home-search-trigger');
    if (searchTrigger) {
      searchTrigger.style.display = tabName === 'home' ? 'flex' : 'none';
    }

    // Refresh contents
    if (tabName === 'home') renderHomeScreen();
    if (tabName === 'categories') renderCategoriesScreen();
    if (tabName === 'search') renderSearchScreen();
    if (tabName === 'saved') renderSavedScreen();
  }

  // 4. Screen Renderers

  // --- HOME SCREEN ---
  function renderHomeScreen() {
    // 4.1 Popular categories
    const popularContainer = document.getElementById('popular-categories-strip');
    if (popularContainer) {
      const popularCats = categories.filter((c) => c.isPopular).slice(0, 8);
      popularContainer.innerHTML = popularCats
        .map(
          (c) => `
        <div class="category-tile" data-cat-id="${c.id}">
          <div class="category-icon-box">${getCategoryIcon(c.iconKey)}</div>
          <div class="category-title">${c.name}</div>
        </div>
      `
        )
        .join('');

      popularContainer.querySelectorAll('.category-tile').forEach((tile) => {
        tile.addEventListener('click', () => {
          const cid = tile.getAttribute('data-cat-id');
          state.searchFilters.categoryId = cid;
          state.searchFilters.query = '';
          selectTab('search');
        });
      });
    }

    // 4.2 Sponsored Section
    const sponsoredContainer = document.getElementById('sponsored-provider-container');
    const sponsoredSection = document.getElementById('sponsored-section-block');
    const sponsoredProvider = state.providers.find(
      (p) => p.isSponsored && p.status === 'published' && (!state.isProviderPaused || p.id !== 'provider-seed-000')
    );

    if (sponsoredProvider && sponsoredContainer) {
      sponsoredSection.style.display = 'block';
      sponsoredContainer.innerHTML = renderProviderCard(sponsoredProvider, true);
    } else if (sponsoredSection) {
      sponsoredSection.style.display = 'none';
    }

    // 4.3 Organic Providers (Serving current locality)
    const organicContainer = document.getElementById('organic-providers-container');
    if (organicContainer) {
      const organicList = state.providers.filter(
        (p) =>
          !p.isSponsored &&
          p.status === 'published' &&
          (p.baseLocalityId === state.localityId || (p.serviceAreaIds && p.serviceAreaIds.includes(state.localityId)))
      );

      if (organicList.length === 0) {
        organicContainer.innerHTML = `
          <div class="empty-state" style="padding: 24px 0;">
            <p style="font-size: 13px; color: var(--text-secondary);">${t('noResults')}</p>
          </div>
        `;
      } else {
        organicContainer.innerHTML = organicList.map((p) => renderProviderCard(p, false)).join('');
      }
    }

    attachCardEventListeners();
  }

  // Provider Card HTML Template
  function renderProviderCard(p, isSponsored = false) {
    const isSaved = state.savedIds.has(p.id);
    const category = categories.find((c) => p.categories && p.categories.includes(c.id));
    const catName = category ? category.name : 'Local Service';
    const baseLoc = localities.find((l) => l.id === p.baseLocalityId);
    const locName = baseLoc ? baseLoc.name : 'Mumbai';

    const startingPrice =
      p.prices && Object.values(p.prices).length > 0 ? `₹${Object.values(p.prices)[0]}` : null;

    const initials = p.name
      .split(' ')
      .map((w) => w[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();

    return `
      <div class="provider-card ${isSponsored ? 'sponsored' : ''}" data-provider-id="${p.id}">
        ${
          isSponsored
            ? `
          <div class="sponsored-badge-row">
            <span class="sponsored-tag">⭐ ${t('sponsored')}</span>
            <span class="why-sponsored-link" data-action="why-sponsored">${t('whySponsored')}</span>
          </div>
        `
            : ''
        }
        <div class="provider-header">
          <div class="provider-avatar">${initials}</div>
          <div class="provider-main-info">
            <div class="provider-name-row">
              <h3 class="provider-name">${p.name}</h3>
              <button class="btn-bookmark ${isSaved ? 'saved' : ''}" data-provider-id="${p.id}" title="Save Provider">
                ${isSaved ? '★' : '☆'}
              </button>
            </div>
            <div class="provider-meta-row">
              <span class="trade-pill">${catName}</span>
              <span class="verified-pill">✓ ${t('phoneVerified')}</span>
              <span>•</span>
              <span>📍 ${locName}</span>
            </div>
          </div>
        </div>

        <p class="provider-description">${p.description || ''}</p>

        <div class="provider-footer">
          <div class="provider-price-tag">
            ${startingPrice ? `${t('startingFrom')} <strong>${startingPrice}</strong>` : `<span>${p.homeVisits ? t('homeVisits') : t('workshopOnly')}</span>`}
          </div>
          <div class="provider-actions">
            <button class="btn-action-call" data-action="call" data-phone="${p.phone}">
              <span>📞</span> ${t('callNow')}
            </button>
            ${
              p.whatsapp
                ? `
              <button class="btn-action-whatsapp" data-action="whatsapp" data-phone="${p.phone}">
                <span>💬</span> ${t('whatsapp')}
              </button>
            `
                : ''
            }
          </div>
        </div>
      </div>
    `;
  }

  function attachCardEventListeners() {
    // Card click -> open profile details
    document.querySelectorAll('.provider-card').forEach((card) => {
      card.addEventListener('click', (e) => {
        // Prevent if clicking on buttons or links
        if (e.target.closest('button') || e.target.closest('.why-sponsored-link')) return;
        const pid = card.getAttribute('data-provider-id');
        openProviderProfile(pid);
      });
    });

    // Bookmark toggle
    document.querySelectorAll('.btn-bookmark').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const pid = btn.getAttribute('data-provider-id');
        toggleBookmark(pid, btn);
      });
    });

    // Call / WhatsApp demo buttons
    document.querySelectorAll('[data-action="call"]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const phone = btn.getAttribute('data-phone');
        openDemoContactDialog(phone, 'call');
      });
    });

    document.querySelectorAll('[data-action="whatsapp"]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const phone = btn.getAttribute('data-phone');
        openDemoContactDialog(phone, 'whatsapp');
      });
    });

    // Why sponsored link
    document.querySelectorAll('[data-action="why-sponsored"]').forEach((el) => {
      el.addEventListener('click', (e) => {
        e.stopPropagation();
        openModal('modal-why-sponsored');
      });
    });
  }

  function toggleBookmark(pid, btnEl) {
    if (state.savedIds.has(pid)) {
      state.savedIds.delete(pid);
      btnEl.classList.remove('saved');
      btnEl.textContent = '☆';
    } else {
      state.savedIds.add(pid);
      btnEl.classList.add('saved');
      btnEl.textContent = '★';
    }
    localStorage.setItem('ls_saved', JSON.stringify([...state.savedIds]));
    if (state.activeTab === 'saved') renderSavedScreen();
  }

  // --- CATEGORIES SCREEN ---
  function renderCategoriesScreen() {
    const catalogContainer = document.getElementById('category-groups-catalog');
    if (!catalogContainer) return;

    catalogContainer.innerHTML = groups
      .map((g) => {
        const groupCats = categories.filter((c) => c.groupId === g.id);
        return `
          <div class="category-group-card">
            <div class="category-group-header">
              <span class="category-group-icon">${getCategoryIcon(g.iconKey)}</span>
              <div>
                <div class="category-group-title">${g.name}</div>
                <div class="category-group-desc">${g.description}</div>
              </div>
            </div>
            <div class="category-items-grid">
              ${groupCats
                .map((c) => {
                  const count = state.providers.filter(
                    (p) => p.status === 'published' && p.categories && p.categories.includes(c.id)
                  ).length;
                  return `
                    <div class="category-item-cell" data-cat-id="${c.id}">
                      <span style="font-size: 18px;">${getCategoryIcon(c.iconKey)}</span>
                      <div>
                        <div class="category-item-name">${c.name}</div>
                        <div class="category-item-count">${count} verified</div>
                      </div>
                    </div>
                  `;
                })
                .join('')}
            </div>
          </div>
        `;
      })
      .join('');

    catalogContainer.querySelectorAll('.category-item-cell').forEach((cell) => {
      cell.addEventListener('click', () => {
        const cid = cell.getAttribute('data-cat-id');
        state.searchFilters.categoryId = cid;
        state.searchFilters.query = '';
        selectTab('search');
      });
    });
  }

  // --- SEARCH & FILTER SCREEN ---
  function renderSearchScreen() {
    const query = state.searchFilters.query.toLowerCase().trim();
    const catId = state.searchFilters.categoryId;
    const homeVisitsOnly = state.searchFilters.homeVisits;
    const openNowOnly = state.searchFilters.openNow;
    const filterLocality = state.searchFilters.localityId;

    // Filter logic matching LocalSaathi search specs
    const results = state.providers.filter((p) => {
      if (p.status !== 'published') return false;

      // Locality filter
      if (filterLocality && p.baseLocalityId !== filterLocality && (!p.serviceAreaIds || !p.serviceAreaIds.includes(filterLocality))) {
        return false;
      }

      // Category filter
      if (catId && (!p.categories || !p.categories.includes(catId))) {
        return false;
      }

      // Home visits
      if (homeVisitsOnly && !p.homeVisits) return false;

      // Text query multi-token match
      if (query) {
        const nameMatch = p.name.toLowerCase().includes(query);
        const descMatch = (p.description || '').toLowerCase().includes(query);

        // Keywords in category
        const catMatch = (p.categories || []).some((cKey) => {
          const cat = categories.find((c) => c.id === cKey);
          if (!cat) return false;
          if (cat.name.toLowerCase().includes(query)) return true;
          return (cat.keywords || []).some((kw) => kw.toLowerCase().includes(query));
        });

        // Locality name match
        const locMatch = (p.serviceAreaIds || []).some((areaId) => {
          const loc = localities.find((l) => l.id === areaId);
          return loc && loc.name.toLowerCase().includes(query);
        });

        if (!nameMatch && !descMatch && !catMatch && !locMatch) return false;
      }

      return true;
    });

    // Update filter UI chips
    const clearBtn = document.getElementById('filter-clear-btn');
    const hasActiveFilters = !!(query || catId || homeVisitsOnly || openNowOnly || filterLocality);
    if (clearBtn) clearBtn.style.display = hasActiveFilters ? 'inline-flex' : 'none';

    const homeVisitsBtn = document.getElementById('filter-home-visits-btn');
    if (homeVisitsBtn) homeVisitsBtn.classList.toggle('active', homeVisitsOnly);

    const openNowBtn = document.getElementById('filter-open-now-btn');
    if (openNowBtn) openNowBtn.classList.toggle('active', openNowOnly);

    const countEl = document.getElementById('search-results-count');
    if (countEl) countEl.textContent = `${results.length} ${t('results')}`;

    const descEl = document.getElementById('search-active-filter-desc');
    if (descEl) {
      const activeCat = categories.find((c) => c.id === catId);
      descEl.textContent = activeCat ? `Filter: ${activeCat.name}` : '';
    }

    const resultsContainer = document.getElementById('search-results-container');
    if (resultsContainer) {
      if (results.length === 0) {
        resultsContainer.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">🔍</div>
            <h3 class="empty-state-title">${t('noResults')}</h3>
            <p class="empty-state-desc">${t('noResultsSub')}</p>
          </div>
        `;
      } else {
        resultsContainer.innerHTML = results.map((p) => renderProviderCard(p, p.isSponsored)).join('');
        attachCardEventListeners();
      }
    }
  }

  // --- SAVED SCREEN ---
  function renderSavedScreen() {
    const savedContainer = document.getElementById('saved-providers-container');
    if (!savedContainer) return;

    const savedList = state.providers.filter(
      (p) => state.savedIds.has(p.id) && p.status === 'published'
    );

    if (savedList.length === 0) {
      savedContainer.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">🔖</div>
          <h3 class="empty-state-title">${t('noSaved')}</h3>
          <p class="empty-state-desc">${t('noSavedSub')}</p>
          <button class="btn-empty-action" id="btn-browse-saved-empty">Browse Services</button>
        </div>
      `;
      const btn = document.getElementById('btn-browse-saved-empty');
      if (btn) btn.addEventListener('click', () => selectTab('home'));
    } else {
      savedContainer.innerHTML = savedList.map((p) => renderProviderCard(p, false)).join('');
      attachCardEventListeners();
    }
  }

  // 5. Modals & Sheets Logic
  function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add('open');
  }

  function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.remove('open');
  }

  function setupModals() {
    // Backdrop click to close
    document.querySelectorAll('.modal-backdrop').forEach((backdrop) => {
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          backdrop.classList.remove('open');
        }
      });
    });

    // Close buttons
    const bindClose = (btnId, modalId) => {
      const btn = document.getElementById(btnId);
      if (btn) btn.addEventListener('click', () => closeModal(modalId));
    };

    bindClose('btn-close-profile', 'modal-profile');
    bindClose('btn-close-demo-contact', 'modal-demo-contact');
    bindClose('btn-close-why-sponsored', 'modal-why-sponsored');
    bindClose('btn-close-locality', 'modal-locality-picker');
    bindClose('btn-close-onboarding', 'modal-onboarding');

    const whySponsoredBtn = document.getElementById('btn-why-sponsored');
    if (whySponsoredBtn) {
      whySponsoredBtn.addEventListener('click', () => openModal('modal-why-sponsored'));
    }

    const changeLocalityBtn = document.getElementById('btn-change-locality');
    if (changeLocalityBtn) {
      changeLocalityBtn.addEventListener('click', () => openLocalityPicker());
    }

    const accountLocalityItem = document.getElementById('account-item-locality');
    if (accountLocalityItem) {
      accountLocalityItem.addEventListener('click', () => openLocalityPicker());
    }

    const accountOnboardingItem = document.getElementById('account-item-onboarding');
    if (accountOnboardingItem) {
      accountOnboardingItem.addEventListener('click', () => openOnboardingWizard());
    }

    const headerOnboardingBtn = document.getElementById('btn-open-onboarding');
    if (headerOnboardingBtn) {
      headerOnboardingBtn.addEventListener('click', () => openOnboardingWizard());
    }
  }

  // --- Provider Profile Sheet ---
  function openProviderProfile(pid) {
    const p = state.providers.find((item) => item.id === pid);
    if (!p) return;

    state.activeProfileId = pid;
    const category = categories.find((c) => p.categories && p.categories.includes(c.id));
    const catName = category ? category.name : 'Local Service';

    document.getElementById('sheet-provider-category').textContent = catName;
    document.getElementById('sheet-provider-name').textContent = p.name;
    document.getElementById('sheet-provider-phone').textContent = p.phone;
    document.getElementById('sheet-provider-desc').textContent = p.description || '';

    const initials = p.name
      .split(' ')
      .map((w) => w[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();
    document.getElementById('sheet-provider-avatar').textContent = initials;

    // Healthcare block
    const hcBox = document.getElementById('sheet-healthcare-box');
    if (p.healthcare) {
      hcBox.style.display = 'block';
      document.getElementById('sheet-healthcare-title').textContent =
        p.healthcare.clinicName || p.healthcare.specialty || '';
      document.getElementById('sheet-healthcare-qual').textContent =
        p.healthcare.qualification || '';
    } else {
      hcBox.style.display = 'none';
    }

    // Starting rates
    const ratesContainer = document.getElementById('sheet-provider-rates');
    if (ratesContainer) {
      if (p.prices && Object.keys(p.prices).length > 0) {
        ratesContainer.innerHTML = Object.entries(p.prices)
          .map(([key, val]) => {
            const cat = categories.find((c) => c.id === key);
            return `
            <div class="rate-item">
              <span>${cat ? cat.name : key} Service / Inspection</span>
              <span class="rate-price">₹${val}</span>
            </div>
          `;
          })
          .join('');
      } else {
        ratesContainer.innerHTML = `<div style="font-size:12px; color:var(--text-secondary);">Rates quoted on inspection / inquiry.</div>`;
      }
    }

    // Service areas
    const areasContainer = document.getElementById('sheet-provider-areas');
    if (areasContainer) {
      areasContainer.innerHTML = (p.serviceAreaIds || [p.baseLocalityId])
        .map((areaId) => {
          const loc = localities.find((l) => l.id === areaId);
          return `<span class="area-chip">📍 ${loc ? loc.name : areaId}</span>`;
        })
        .join('');
    }

    // Languages
    const langsEl = document.getElementById('sheet-provider-languages');
    if (langsEl) {
      langsEl.textContent = (p.languages || ['Hindi', 'English']).join(', ');
    }

    // Action buttons inside sheet
    const callBtn = document.getElementById('btn-sheet-call');
    const waBtn = document.getElementById('btn-sheet-whatsapp');

    callBtn.onclick = () => openDemoContactDialog(p.phone, 'call');
    waBtn.onclick = () => openDemoContactDialog(p.phone, 'whatsapp');

    // Report button
    const reportBtn = document.getElementById('btn-report-listing');
    if (reportBtn) {
      reportBtn.onclick = () => {
        alert(t('reportSuccess'));
        closeModal('modal-profile');
      };
    }

    openModal('modal-profile');
  }

  // --- Demo Contact Dialog ---
  function openDemoContactDialog(phone, type) {
    const numEl = document.getElementById('demo-contact-number');
    if (numEl) numEl.textContent = `${type === 'call' ? '📞 Dialling' : '💬 WhatsApp'}: ${phone}`;
    openModal('modal-demo-contact');
  }

  // --- Locality Picker Sheet ---
  function openLocalityPicker() {
    const mumbaiList = document.getElementById('mumbai-localities-list');
    const upcomingList = document.getElementById('upcoming-cities-list');

    // Mumbai localities
    const mumbaiLocs = localities.filter((l) => l.cityId === 'mh-mumbai').slice(0, 16);
    if (mumbaiList) {
      mumbaiList.innerHTML = mumbaiLocs
        .map(
          (loc) => `
        <div class="account-menu-item" style="padding:10px 14px; border-radius:var(--radius-sm);" data-loc-id="${loc.id}">
          <div style="font-size:13.5px; font-weight:600; color:var(--text-primary);">${loc.name}</div>
          ${loc.id === state.localityId ? `<span style="color:var(--success); font-weight:700;">✓ Active</span>` : `<span>›</span>`}
        </div>
      `
        )
        .join('');

      mumbaiList.querySelectorAll('[data-loc-id]').forEach((item) => {
        item.addEventListener('click', () => {
          const lid = item.getAttribute('data-loc-id');
          state.localityId = lid;
          state.cityId = 'mh-mumbai';
          closeModal('modal-locality-picker');
          updateLocalityLabels();
          renderHomeScreen();
          if (state.activeTab === 'search') renderSearchScreen();
        });
      });
    }

    // Upcoming cities
    const comingSoonCities = cities.filter((c) => c.launchStatus === 'comingSoon').slice(0, 6);
    if (upcomingList) {
      upcomingList.innerHTML = comingSoonCities
        .map(
          (city) => `
        <div class="account-menu-item" style="padding:10px 14px; border-radius:var(--radius-sm);" data-city-name="${city.name}">
          <div>
            <div style="font-size:13.5px; font-weight:600; color:var(--text-primary);">${city.name}</div>
            <div style="font-size:11px; color:var(--text-tertiary);">Launch market coming soon</div>
          </div>
          <span style="font-size:11px; background:var(--warning-surface); color:var(--warning); padding:2px 8px; border-radius:4px; font-weight:700;">Coming Soon</span>
        </div>
      `
        )
        .join('');

      upcomingList.querySelectorAll('[data-city-name]').forEach((item) => {
        item.addEventListener('click', () => {
          const cname = item.getAttribute('data-city-name');
          closeModal('modal-locality-picker');
          openUnsupportedCityDialog(cname);
        });
      });
    }

    openModal('modal-locality-picker');
  }

  function openUnsupportedCityDialog(cityName) {
    const nameEl = document.getElementById('unsupported-city-name');
    if (nameEl) nameEl.textContent = cityName;

    const requestBtn = document.getElementById('btn-request-city');
    if (requestBtn) {
      requestBtn.onclick = () => {
        alert(t('requestSubmitted'));
        closeModal('modal-unsupported-city');
      };
    }

    const browseMumbaiBtn = document.getElementById('btn-browse-mumbai-anyway');
    if (browseMumbaiBtn) {
      browseMumbaiBtn.onclick = () => {
        state.cityId = 'mh-mumbai';
        state.localityId = 'mh-mumbai-andheri-west';
        closeModal('modal-unsupported-city');
        updateLocalityLabels();
        renderHomeScreen();
      };
    }

    openModal('modal-unsupported-city');
  }

  // --- Provider Onboarding Wizard ---
  function openOnboardingWizard() {
    setWizardStep(1);

    // Populate category select
    const catSelect = document.getElementById('wiz-category-select');
    if (catSelect) {
      catSelect.innerHTML = categories
        .map((c) => `<option value="${c.id}">${c.name}</option>`)
        .join('');
    }

    // Populate base locality
    const baseLocSelect = document.getElementById('wiz-base-locality');
    if (baseLocSelect) {
      const mumbaiLocs = localities.filter((l) => l.cityId === 'mh-mumbai');
      baseLocSelect.innerHTML = mumbaiLocs
        .map((l) => `<option value="${l.id}">${l.name}</option>`)
        .join('');
    }

    openModal('modal-onboarding');
  }

  function setWizardStep(stepNum) {
    for (let i = 1; i <= 4; i++) {
      const stepEl = document.getElementById(`wiz-step-${i}`);
      const progEl = document.getElementById(`prog-${i}`);
      if (stepEl) stepEl.style.display = i === stepNum ? 'block' : 'none';
      if (progEl) progEl.classList.toggle('active', i <= stepNum);
    }
    const successEl = document.getElementById('wiz-step-success');
    if (successEl) successEl.style.display = stepNum === 5 ? 'block' : 'none';
  }

  function setupWizardHandlers() {
    // Step 1 -> 2: Send OTP
    const btnSendOtp = document.getElementById('btn-wiz-send-otp');
    if (btnSendOtp) {
      btnSendOtp.addEventListener('click', () => {
        const phone = document.getElementById('wiz-phone-input').value.trim();
        if (phone.length < 10) {
          alert('Please enter a valid 10-digit mobile number');
          return;
        }
        state.wizardData.phone = `+91${phone}`;
        setWizardStep(2);
      });
    }

    // Step 2: Auto-fill OTP
    const btnAutoOtp = document.getElementById('btn-wiz-autofill-otp');
    if (btnAutoOtp) {
      btnAutoOtp.addEventListener('click', () => {
        document.getElementById('wiz-otp-input').value = '123456';
      });
    }

    // Step 2 -> 3: Verify OTP
    const btnVerifyOtp = document.getElementById('btn-wiz-verify-otp');
    if (btnVerifyOtp) {
      btnVerifyOtp.addEventListener('click', () => {
        const otp = document.getElementById('wiz-otp-input').value.trim();
        if (otp !== '123456') {
          alert('Invalid OTP. Use the simulation code: 123456');
          return;
        }
        setWizardStep(3);
      });
    }

    // Step 3 -> 4: Business details
    const btnToLoc = document.getElementById('btn-wiz-to-location');
    if (btnToLoc) {
      btnToLoc.addEventListener('click', () => {
        const name = document.getElementById('wiz-name-input').value.trim();
        if (!name) {
          alert('Please enter your business or provider name');
          return;
        }
        state.wizardData.name = name;
        state.wizardData.category = document.getElementById('wiz-category-select').value;
        state.wizardData.description = document.getElementById('wiz-desc-input').value.trim();
        setWizardStep(4);
      });
    }

    // Step 4 -> Publish
    const btnPublish = document.getElementById('btn-wiz-publish');
    if (btnPublish) {
      btnPublish.addEventListener('click', () => {
        const baseLoc = document.getElementById('wiz-base-locality').value;
        const homeVisits = document.getElementById('wiz-homevisits-check').checked;

        const newProfile = {
          id: `provider-user-${Date.now()}`,
          name: state.wizardData.name,
          phone: state.wizardData.phone || '+919820012345',
          categories: [state.wizardData.category],
          baseLocalityId: baseLoc,
          serviceAreaIds: [baseLoc],
          description: state.wizardData.description || 'Verified local service provider.',
          languages: ['Hindi', 'English', 'Marathi'],
          hoursType: 'standard',
          homeVisits: homeVisits,
          whatsapp: true,
          prices: { [state.wizardData.category]: 299 },
          status: 'published',
          isSponsored: false,
        };

        state.providers.unshift(newProfile);
        state.localityId = baseLoc;
        state.activeProfileId = newProfile.id;

        setWizardStep(5);
      });
    }

    // Step 5: View listing
    const btnViewListing = document.getElementById('btn-wiz-view-listing');
    if (btnViewListing) {
      btnViewListing.addEventListener('click', () => {
        closeModal('modal-onboarding');
        renderHomeScreen();
        if (state.activeProfileId) {
          openProviderProfile(state.activeProfileId);
        }
      });
    }
  }

  // 6. Provider Dashboard Mode (Toggle Pause / Live)
  function setupDashboardMode() {
    const btnToggle = document.getElementById('btn-toggle-pause');
    const badge = document.getElementById('provider-status-badge');
    const textEl = document.getElementById('status-text');
    const dotEl = document.getElementById('status-dot');

    if (btnToggle) {
      btnToggle.addEventListener('click', () => {
        state.isProviderPaused = !state.isProviderPaused;

        // Toggle sponsored provider Sharma Plumbing
        const p = state.providers.find((item) => item.id === 'provider-seed-000');
        if (p) {
          p.status = state.isProviderPaused ? 'paused' : 'published';
        }

        if (state.isProviderPaused) {
          badge.className = 'status-indicator-tag paused';
          textEl.textContent = t('statusPaused');
          dotEl.textContent = '⏸️';
        } else {
          badge.className = 'status-indicator-tag live';
          textEl.textContent = t('statusActive');
          dotEl.textContent = '🟢';
        }

        renderHomeScreen();
      });
    }
  }

  // 7. General Event Bindings
  function bindGlobalEvents() {
    // Language Switcher
    const langSelect = document.getElementById('lang-selector');
    if (langSelect) {
      langSelect.value = state.language;
      langSelect.addEventListener('change', (e) => {
        state.language = e.target.value;
        localStorage.setItem('ls_lang', state.language);
        applyTranslations();
        renderHomeScreen();
        if (state.activeTab === 'search') renderSearchScreen();
        if (state.activeTab === 'categories') renderCategoriesScreen();
      });
    }

    // View Mode Toggle (Mobile Frame vs Expanded Full Web)
    const btnMobile = document.getElementById('btn-view-mobile');
    const btnFull = document.getElementById('btn-view-full');

    if (btnMobile && btnFull) {
      btnMobile.addEventListener('click', () => {
        document.body.classList.remove('full-web-mode');
        btnMobile.classList.add('active');
        btnFull.classList.remove('active');
      });

      btnFull.addEventListener('click', () => {
        document.body.classList.add('full-web-mode');
        btnFull.classList.add('active');
        btnMobile.classList.remove('active');
      });
    }

    // Bottom Navigation Bar Clicks
    document.querySelectorAll('.nav-item').forEach((item) => {
      item.addEventListener('click', () => {
        const tab = item.getAttribute('data-tab');
        selectTab(tab);
      });
    });

    // Home Search Bar Trigger
    const homeSearchTrigger = document.getElementById('home-search-trigger');
    if (homeSearchTrigger) {
      homeSearchTrigger.addEventListener('click', () => {
        selectTab('search');
        setTimeout(() => {
          const input = document.getElementById('live-search-input');
          if (input) input.focus();
        }, 100);
      });
    }

    // Action "View All Categories" on Home
    const viewAllCatsBtn = document.getElementById('action-view-all-cats');
    if (viewAllCatsBtn) {
      viewAllCatsBtn.addEventListener('click', (e) => {
        e.preventDefault();
        selectTab('categories');
      });
    }

    // Search input live typing
    const searchInput = document.getElementById('live-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        state.searchFilters.query = e.target.value;
        renderSearchScreen();
      });
    }

    // Filter chip: Home visits
    const filterHomeVisits = document.getElementById('filter-home-visits-btn');
    if (filterHomeVisits) {
      filterHomeVisits.addEventListener('click', () => {
        state.searchFilters.homeVisits = !state.searchFilters.homeVisits;
        renderSearchScreen();
      });
    }

    // Filter chip: Open now
    const filterOpenNow = document.getElementById('filter-open-now-btn');
    if (filterOpenNow) {
      filterOpenNow.addEventListener('click', () => {
        state.searchFilters.openNow = !state.searchFilters.openNow;
        renderSearchScreen();
      });
    }

    // Filter chip: Locality dropdown picker
    const filterLocalityBtn = document.getElementById('filter-locality-btn');
    if (filterLocalityBtn) {
      filterLocalityBtn.addEventListener('click', () => {
        openLocalityPicker();
      });
    }

    // Filter chip: Clear all
    const filterClearBtn = document.getElementById('filter-clear-btn');
    if (filterClearBtn) {
      filterClearBtn.addEventListener('click', () => {
        state.searchFilters.query = '';
        state.searchFilters.categoryId = '';
        state.searchFilters.localityId = '';
        state.searchFilters.homeVisits = false;
        state.searchFilters.openNow = false;
        if (searchInput) searchInput.value = '';
        renderSearchScreen();
      });
    }

    // Live clock in phone status bar
    function updateClock() {
      const clockEl = document.getElementById('status-clock');
      if (clockEl) {
        const now = new Date();
        const hrs = now.getHours().toString().padStart(2, '0');
        const mins = now.getMinutes().toString().padStart(2, '0');
        clockEl.textContent = `${hrs}:${mins}`;
      }
    }
    updateClock();
    setInterval(updateClock, 30000);
  }

  // 8. Bootstrap App
  function init() {
    applyTranslations();
    setupModals();
    setupWizardHandlers();
    setupDashboardMode();
    bindGlobalEvents();
    renderHomeScreen();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
