const component = () => {
	return {
		plugins: [],
		info: undefined,
		pid: undefined,
		chapters: undefined, // undefined: not searched yet, []: empty
		manga: undefined, // undefined: not searched yet, []: empty
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

		init() {
			const tableObserver = new MutationObserver(() => {
				console.log('table mutated');
				$('#selectable').selectable({
					filter: 'tr'
				});
			});
			tableObserver.observe($('table').get(0), {
				childList: true,
				subtree: true
			});
			fetch(`${base_url}api/admin/plugin`)
				.then(res => res.json())
				.then(data => {
					if (!data.success)
						throw new Error(data.error);
					this.plugins = data.plugins;

					const pid = localStorage.getItem('plugin');
					if (pid && this.plugins.map(p => p.id).includes(pid))
						return this.loadPlugin(pid);

					if (this.plugins.length > 0)
						this.loadPlugin(this.plugins[0].id);
				})
				.catch(e => {
					alert('danger', `Failed to list the available plugins. Error: ${e}`);
				});
		},
		loadPlugin(pid) {
			fetch(`${base_url}api/admin/plugin/info?${new URLSearchParams({
				plugin: pid
			})}`)
				.then(res => res.json())
				.then(data => {
					if (!data.success)
						throw new Error(data.error);
					this.info = data.info;
					this.pid = pid;
				})
				.catch(e => {
					alert('danger', `Failed to get plugin metadata. Error: ${e}`);
				});
		},
		pluginChanged() {
			this.loadPlugin(this.pid);
			localStorage.setItem('plugin', this.pid);
		},
		get chapterKeys() {
			if (this.allChapters.length < 1) return [];
			return Object.keys(this.allChapters[0]).filter(k => !['manga_title'].includes(k));
		},
		searchChapters(query) {
			this.searching = true;
			this.allChapters = [];
			this.chapters = undefined;
			this.listManga = false;
			fetch(`${base_url}api/admin/plugin/list?${new URLSearchParams({
				plugin: this.pid,
				query: query
			})}`)
				.then(res => res.json())
				.then(data => {
					if (!data.success)
						throw new Error(data.error);
					try {
						this.mangaTitle = data.chapters[0].manga_title;
						if (!this.mangaTitle) throw new Error();
					} catch (e) {
						this.mangaTitle = data.title;
					}

					this.allChapters = data.chapters;
					this.chapters = data.chapters;
				})
				.catch(e => {
					alert('danger', `Failed to list chapters. Error: ${e}`);
				})
				.finally(() => {
					this.searching = false;
				});
		},
		searchManga() {
			this.searching = true;
			this.allChapters = [];
			this.chapters = undefined;
			this.manga = undefined;
			fetch(`${base_url}api/admin/plugin/search?${new URLSearchParams({
				plugin: this.pid,
				query: this.query
			})}`)
				.then(res => res.json())
				.then(data => {
					if (!data.success)
						throw new Error(data.error);
					this.manga = data.manga;
					this.listManga = true;
				})
				.catch(e => {
					alert('danger', `Search failed. Error: ${e}`);
				})
				.finally(() => {
					this.searching = false;
				});
		},
		search() {
			this.manga = undefined;
			if (this.info.version === 1) {
				this.searchChapters(this.query);
			} else {
				this.searchManga();
			}
		},
		selectAll() {
			$('tbody > tr').each((i, e) => {
				$(e).addClass('ui-selected');
			});
		},
		clearSelection() {
			$('tbody > tr').each((i, e) => {
				$(e).removeClass('ui-selected');
			});
		},
		download() {
			const selected = $('tbody > tr.ui-selected').get();
			if (selected.length === 0) return;

			UIkit.modal.confirm(`Download ${selected.length} selected chapters?`).then(() => {
				const ids = selected.map(e => e.id);
				const chapters = this.chapters.filter(c => ids.includes(c.id));
				console.log(chapters);
				this.adding = true;
				fetch(`${base_url}api/admin/plugin/download`, {
						method: 'POST',
						body: JSON.stringify({
							chapters,
							plugin: this.pid,
							title: this.mangaTitle
						}),
						headers: {
							"Content-Type": "application/json"
						}
					})
					.then(res => res.json())
					.then(data => {
						if (!data.success)
							throw new Error(data.error);
						const successCount = parseInt(data.success);
						const failCount = parseInt(data.fail);
						alert('success', `${successCount} of ${successCount + failCount} chapters added to the download queue. You can view and manage your download queue on the <a href="${base_url}admin/downloads">download manager page</a>.`);
					})
					.catch(e => {
						alert('danger', `Failed to add chapters to the download queue. Error: ${e}`);
					})
					.finally(() => {
						this.adding = false;
					});
			})
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
			this.sort(this.chapterKeys[idx], option)
		},
		// Returns an array of filtered but unsorted chapters. Useful when
		// 	reseting the sort options.
		get filteredChapters() {
			let ary = this.allChapters.slice();

			console.log('initial size:', ary.length);
			for (let filter of this.appliedFilters) {
				if (!filter.value) continue;
				if (filter.type === 'array' && filter.value === 'all') continue;

				console.log('applying filter:', filter);

				if (filter.type === 'string') {
					ary = ary.filter(ch => ch[filter.key].toLowerCase().includes(filter.value.toLowerCase()));
				}
				if (filter.type === 'number-min') {
					ary = ary.filter(ch => Number(ch[filter.key]) >= Number(filter.value));
				}
				if (filter.type === 'number-max') {
					ary = ary.filter(ch => Number(ch[filter.key]) <= Number(filter.value));
				}
				if (filter.type === 'date-min') {
					ary = ary.filter(ch => this.parseDate(ch[filter.key]) >= this.parseDate(filter.value));
				}
				if (filter.type === 'date-max') {
					ary = ary.filter(ch => this.parseDate(ch[filter.key]) <= this.parseDate(filter.value));
				}
				if (filter.type === 'array') {
					ary = ary.filter(ch => ch[filter.key].map(s => typeof s === 'string' ? s.toLowerCase() : s).includes(filter.value.toLowerCase()));
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

			// try numbers
			// this must come before the date checks, because any integer would
			// 		also be parsed as a date.
			if (!isNaN(a) && !isNaN(b))
				return Number(a) - Number(b);

			// try dates
			if (!isNaN(this.parseDate(a)) && !isNaN(this.parseDate(b)))
				return this.parseDate(a) - this.parseDate(b);

			const preprocessString = (val) => {
				if (typeof val !== 'string') return val;
				return val.toLowerCase().replace(/\s\s/g, ' ').trim();
			};

			return preprocessString(a) > preprocessString(b) ? 1 : -1;
		},
		fieldType(values) {
			if (values.every(v => !isNaN(v))) return 'number'; // display input for number range
			if (values.every(v => !isNaN(this.parseDate(v)))) return 'date'; // display input for date range
			if (values.every(v => Array.isArray(v))) return 'array'; // display input for contains
			return 'string'; // display input for string searching.
			// for the last two, if the number of options is small enough (say < 50), display a multi-select2
		},
		get filters() {
			if (this.allChapters.length < 1) return [];
			const keys = Object.keys(this.allChapters[0]).filter(k => !['manga_title', 'id'].includes(k));
			return keys.map(k => {
				let values = this.allChapters.map(c => c[k]);
				const type = this.fieldType(values);

				if (type === 'array') {
					// if the type is an array, return the list of available elements
					// example: an array of groups or authors
					values = Array.from(new Set(values.flat().map(v => {
						if (typeof v === 'string') return v.toLowerCase();
					})));
				}

				return {
					key: k,
					type: type,
					values: values
				};
			});
		},
		applyFilters() {
			const values = $('#filter-form input, #filter-form select')
				.get()
				.map(i => ({
					key: i.getAttribute('data-filter-key'),
					value: i.value.trim(),
					type: i.getAttribute('data-filter-type')
				}));
			this.appliedFilters = values;
			this.chapters = this.filteredChapters;
		},
		clearFilters() {
			$('#filter-form input').get().forEach(i => i.value = '');
			this.appliedFilters = [];
			this.chapters = this.filteredChapters;
		},
		mangaSelected(event) {
			const mid = event.currentTarget.getAttribute('data-id');
			this.searchChapters(mid);
		},
		parseDate(str) {
			const regex = /([0-9]+[/\-,\ ][0-9]+[/\-,\ ][0-9]+)|([A-Za-z]+)[/\-,\ ]+[0-9]+(st|nd|rd|th)?[/\-,\ ]+[0-9]+/g;
			// Basic sanity check to make sure it's an actual date.
			// We need this because Date.parse thinks 'Chapter 1' is a date.
			if (!regex.test(str))
				return NaN;
			return Date.parse(str);
		}
	};
};
