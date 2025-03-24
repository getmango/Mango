const component = () => {
  return {
    plugins: [],
    subscribable: false,
    info: undefined,
    pid: undefined,
    chapters: undefined, // undefined: not searched yet, []: empty
    manga: undefined, // undefined: not searched yet, []: empty
    mid: undefined, // id of the selected manga
    allChapters: [],
    query: '',
    mangaTitle: '',
    searching: false,
    adding: false,
    sortOptions: [],
    showFilters: false,
    appliedFilters: [],
    chaptersLimit: 500,
    listManga: false,
    subscribing: false,
    subscriptionName: '',

    init() {
      const tableObserver = new MutationObserver(() => {
        console.log('table mutated');
        $('#selectable').selectable({
          filter: 'tr',
        });
      });
      tableObserver.observe($('table').get(0), {
        childList: true,
        subtree: true,
      });
      fetch(`${base_url}api/admin/plugin`)
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          this.plugins = data.plugins;

          const pid = localStorage.getItem('plugin');
          if (pid && this.plugins.map((p) => p.id).includes(pid))
            return this.loadPlugin(pid);

          if (this.plugins.length > 0) this.loadPlugin(this.plugins[0].id);
        })
        .catch((e) => {
          alert('danger', `Failed to list the available plugins. Error: ${e}`);
        });
    },
    loadPlugin(pid) {
      fetch(
        `${base_url}api/admin/plugin/info?${new URLSearchParams({
          plugin: pid,
        })}`,
      )
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          this.info = data.info;
          this.subscribable = data.subscribable;
          this.pid = pid;
        })
        .catch((e) => {
          alert('danger', `Failed to get plugin metadata. Error: ${e}`);
        });
    },
    pluginChanged() {
      this.manga = undefined;
      this.chapters = undefined;
      this.mid = undefined;
      this.loadPlugin(this.pid);
      localStorage.setItem('plugin', this.pid);
    },
    get chapterKeys() {
      if (this.allChapters.length < 1) return [];
      return Object.keys(this.allChapters[0]).filter(
        (k) => !['manga_title'].includes(k),
      );
    },
    searchChapters(query) {
      this.searching = true;
      this.allChapters = [];
      this.sortOptions = [];
      this.chapters = undefined;
      this.listManga = false;
      fetch(
        `${base_url}api/admin/plugin/list?${new URLSearchParams({
          plugin: this.pid,
          query,
        })}`,
      )
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          try {
            this.mangaTitle = data.chapters[0].manga_title;
            if (!this.mangaTitle) throw new Error();
          } catch (e) {
            this.mangaTitle = data.title;
          }

          this.allChapters = data.chapters;
          this.chapters = data.chapters;
        })
        .catch((e) => {
          alert('danger', `Failed to list chapters. Error: ${e}`);
        })
        .finally(() => {
          this.searching = false;
        });
    },
    searchManga(query) {
      this.searching = true;
      this.allChapters = [];
      this.chapters = undefined;
      this.manga = undefined;
      fetch(
        `${base_url}api/admin/plugin/search?${new URLSearchParams({
          plugin: this.pid,
          query,
        })}`,
      )
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          this.manga = data.manga;
          this.listManga = true;
        })
        .catch((e) => {
          alert('danger', `Search failed. Error: ${e}`);
        })
        .finally(() => {
          this.searching = false;
        });
    },
    search() {
      const query = this.query.trim();
      if (!query) return;

      this.manga = undefined;
      this.mid = undefined;
      if (this.info.version === 1) {
        this.searchChapters(query);
      } else {
        this.searchManga(query);
      }
    },
    selectAll() {
      $('tbody#selectable > tr').each((i, e) => {
        $(e).addClass('ui-selected');
      });
    },
    clearSelection() {
      $('tbody#selectable > tr').each((i, e) => {
        $(e).removeClass('ui-selected');
      });
    },
    download() {
      const selected = $('tbody#selectable > tr.ui-selected').get();
      if (selected.length === 0) return;

      UIkit.modal
        .confirm(`Download ${selected.length} selected chapters?`)
        .then(() => {
          const ids = selected.map((e) => e.id);
          const chapters = this.chapters.filter((c) => ids.includes(c.id));
          console.log(chapters);
          this.adding = true;
          fetch(`${base_url}api/admin/plugin/download`, {
            method: 'POST',
            body: JSON.stringify({
              chapters,
              plugin: this.pid,
              title: this.mangaTitle,
            }),
            headers: {
              'Content-Type': 'application/json',
            },
          })
            .then((res) => res.json())
            .then((data) => {
              if (!data.success) throw new Error(data.error);
              const successCount = parseInt(data.success);
              const failCount = parseInt(data.fail);
              alert(
                'success',
                `${successCount} of ${
                  successCount + failCount
                } chapters added to the download queue. You can view and manage your download queue on the <a href="${base_url}admin/downloads">download manager page</a>.`,
              );
            })
            .catch((e) => {
              alert(
                'danger',
                `Failed to add chapters to the download queue. Error: ${e}`,
              );
            })
            .finally(() => {
              this.adding = false;
            });
        });
    },
    thClicked(event) {
      const idx = parseInt(event.currentTarget.id.split('-')[1]);
      if (idx === undefined || isNaN(idx)) return;
      const curOption = this.sortOptions[idx];
      let option;
      this.sortOptions = [];
      switch (curOption) {
        case 1:
          option = -1;
          break;
        case -1:
          option = 0;
          break;
        default:
          option = 1;
      }
      this.sortOptions[idx] = option;
      this.sort(this.chapterKeys[idx], option);
    },
    // Returns an array of filtered but unsorted chapters. Useful when
    // 	reseting the sort options.
    get filteredChapters() {
      let ary = this.allChapters.slice();

      console.log('initial size:', ary.length);
      for (let filter of this.appliedFilters) {
        if (!filter.value) continue;
        if (filter.type === 'array' && filter.value === 'all') continue;
        if (filter.type.startsWith('number') && isNaN(filter.value)) continue;

        if (filter.type === 'string') {
          ary = ary.filter((ch) =>
            ch[filter.key].toLowerCase().includes(filter.value.toLowerCase()),
          );
        }
        if (filter.type === 'number-min') {
          ary = ary.filter(
            (ch) => Number(ch[filter.key]) >= Number(filter.value),
          );
        }
        if (filter.type === 'number-max') {
          ary = ary.filter(
            (ch) => Number(ch[filter.key]) <= Number(filter.value),
          );
        }
        if (filter.type === 'date-min') {
          ary = ary.filter(
            (ch) => Number(ch[filter.key]) >= Number(filter.value),
          );
        }
        if (filter.type === 'date-max') {
          ary = ary.filter(
            (ch) => Number(ch[filter.key]) <= Number(filter.value),
          );
        }
        if (filter.type === 'array') {
          ary = ary.filter((ch) =>
            ch[filter.key]
              .map((s) => (typeof s === 'string' ? s.toLowerCase() : s))
              .includes(filter.value.toLowerCase()),
          );
        }

        console.log('filtered size:', ary.length);
      }

      return ary;
    },
    // option:
    // 	- 1: asending
    // 	- -1: desending
    // 	- 0: unsorted
    sort(key, option) {
      if (option === 0) {
        this.chapters = this.filteredChapters;
        return;
      }

      this.chapters = this.filteredChapters.sort((a, b) => {
        const comp = this.compare(a[key], b[key]);
        return option < 0 ? comp * -1 : comp;
      });
    },
    compare(a, b) {
      if (a === b) return 0;

      // try numbers (also covers dates)
      if (!isNaN(a) && !isNaN(b)) return Number(a) - Number(b);

      const preprocessString = (val) => {
        if (typeof val !== 'string') return val;
        return val.toLowerCase().replace(/\s\s/g, ' ').trim();
      };

      return preprocessString(a) > preprocessString(b) ? 1 : -1;
    },
    fieldType(values) {
      if (values.every((v) => this.numIsDate(v))) return 'date';
      if (values.every((v) => !isNaN(v))) return 'number';
      if (values.every((v) => Array.isArray(v))) return 'array';
      return 'string';
    },
    get filters() {
      if (this.allChapters.length < 1) return [];
      const keys = Object.keys(this.allChapters[0]).filter(
        (k) => !['manga_title', 'id'].includes(k),
      );
      return keys.map((k) => {
        let values = this.allChapters.map((c) => c[k]);
        const type = this.fieldType(values);

        if (type === 'array') {
          // if the type is an array, return the list of available elements
          // example: an array of groups or authors
          values = Array.from(
            new Set(
              values.flat().map((v) => {
                if (typeof v === 'string') return v.toLowerCase();
              }),
            ),
          );
        }

        return {
          key: k,
          type,
          values,
        };
      });
    },
    get filterSettings() {
      return $('#filter-form input:visible, #filter-form select:visible')
        .get()
        .map((i) => {
          const type = i.getAttribute('data-filter-type');
          let value = i.value.trim();
          if (type.startsWith('date'))
            value = value ? Date.parse(value).toString() : '';
          return {
            key: i.getAttribute('data-filter-key'),
            value,
            type,
          };
        });
    },
    applyFilters() {
      this.appliedFilters = this.filterSettings;
      this.chapters = this.filteredChapters;
      this.sortOptions = [];
    },
    clearFilters() {
      $('#filter-form input')
        .get()
        .forEach((i) => (i.value = ''));
      $('#filter-form select').val('all');
      this.appliedFilters = [];
      this.chapters = this.filteredChapters;
      this.sortOptions = [];
    },
    mangaSelected(event) {
      const mid = event.currentTarget.getAttribute('data-id');
      this.mid = mid;
      this.searchChapters(mid);
    },
    subscribe(modal) {
      this.subscribing = true;
      fetch(`${base_url}api/admin/plugin/subscriptions`, {
        method: 'POST',
        body: JSON.stringify({
          filters: this.filterSettings,
          plugin: this.pid,
          name: this.subscriptionName.trim(),
          manga: this.mangaTitle,
          manga_id: this.mid,
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      })
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          alert('success', 'Subscription created');
        })
        .catch((e) => {
          alert('danger', `Failed to subscribe. Error: ${e}`);
        })
        .finally(() => {
          this.subscribing = false;
          UIkit.modal(modal).hide();
        });
    },
    numIsDate(num) {
      return !isNaN(num) && Number(num) > 328896000000; // 328896000000 => 1 Jan, 1980
    },
    renderCell(value) {
      if (this.numIsDate(value))
        return `<span>${moment(Number(value)).format('MMM D, YYYY')}</span>`;
      const maxLength = 40;
      if (value && value.length > maxLength)
        return `<span>${value.substr(
          0,
          maxLength,
        )}...</span><div uk-dropdown>${value}</div>`;
      return `<span>${value}</span>`;
    },
    renderFilterRow(ft) {
      const key = ft.key;
      let type = ft.type;
      switch (type) {
        case 'number-min':
          type = 'number (minimum value)';
          break;
        case 'number-max':
          type = 'number (maximum value)';
          break;
        case 'date-min':
          type = 'minimum date';
          break;
        case 'date-max':
          type = 'maximum date';
          break;
      }
      let value = ft.value;

      if (ft.type.startsWith('number') && isNaN(value)) value = '';
      else if (ft.type.startsWith('date') && value)
        value = moment(Number(value)).format('MMM D, YYYY');

      return `<td>${key}</td><td>${type}</td><td>${value}</td>`;
    },
  };
};
