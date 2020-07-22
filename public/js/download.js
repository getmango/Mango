$(() => {
	$('#search-input').keypress(event => {
		if (event.which === 13) {
			search();
		}
	});
	$('.filter-field').each((i, ele) => {
		$(ele).change(() => {
			buildTable();
		});
	});
});
const selectAll = () => {
	$('tbody > tr').each((i, e) => {
		$(e).addClass('ui-selected');
	});
};
const unselect = () => {
	$('tbody > tr').each((i, e) => {
		$(e).removeClass('ui-selected');
	});
};
const download = () => {
	const selected = $('tbody > tr.ui-selected');
	if (selected.length === 0) return;
	UIkit.modal.confirm(`Download ${selected.length} selected chapters?`).then(() => {
		$('#download-btn').attr('hidden', '');
		$('#download-spinner').removeAttr('hidden');
		const ids = selected.map((i, e) => {
			return $(e).find('td').first().text();
		}).get();
		const chapters = globalChapters.filter(c => ids.indexOf(c.id) >= 0);
		console.log(ids);
		$.ajax({
				type: 'POST',
				url: base_url + 'api/admin/mangadex/download',
				data: JSON.stringify({
					chapters: chapters
				}),
				contentType: "application/json",
				dataType: 'json'
			})
			.done(data => {
				console.log(data);
				if (data.error) {
					alert('danger', `Failed to add chapters to the download queue. Error: ${data.error}`);
					return;
				}
				const successCount = parseInt(data.success);
				const failCount = parseInt(data.fail);
				UIkit.modal.confirm(`${successCount} of ${successCount + failCount} chapters added to the download queue. Proceed to the download manager?`).then(() => {
					window.location.href = base_url + 'admin/downloads';
				});
			})
			.fail((jqXHR, status) => {
				alert('danger', `Failed to add chapters to the download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
			})
			.always(() => {
				$('#download-spinner').attr('hidden', '');
				$('#download-btn').removeAttr('hidden');
			});
	});
};
const toggleSpinner = () => {
	var attr = $('#spinner').attr('hidden');
	if (attr) {
		$('#spinner').removeAttr('hidden');
		$('#search-btn').attr('hidden', '');
	} else {
		$('#search-btn').removeAttr('hidden');
		$('#spinner').attr('hidden', '');
	}
	searching = !searching;
};
var searching = false;
var globalChapters;
const search = () => {
	if (searching) {
		return;
	}
	$('#manga-details').attr('hidden', '');
	$('#filter-form').attr('hidden', '');
	$('table').attr('hidden', '');
	$('#selection-controls').attr('hidden', '');
	$('#filter-notification').attr('hidden', '');
	toggleSpinner();
	const input = $('input').val();

	if (input === "") {
		toggleSpinner();
		return;
	}

	var int_id = -1;

	try {
		const path = new URL(input).pathname;
		const match = /\/title\/([0-9]+)/.exec(path);
		int_id = parseInt(match[1]);
	} catch (e) {
		int_id = parseInt(input);
	}

	if (int_id <= 0 || isNaN(int_id)) {
		alert('danger', 'Please make sure you are using a valid manga ID or manga URL from Mangadex.');
		toggleSpinner();
		return;
	}

	$.getJSON(`${base_url}api/admin/mangadex/manga/${int_id}`)
		.done((data) => {
			if (data.error) {
				alert('danger', 'Failed to get manga info. Error: ' + data.error);
				return;
			}

			const cover = baseURL + data.cover_url;
			$('#cover').attr("src", cover);
			$('#title').text("Title: " + data.title);
			$('#artist').text("Artist: " + data.artist);
			$('#author').text("Author: " + data.author);

			$('#manga-details').removeAttr('hidden');

			console.log(data.chapters);
			globalChapters = data.chapters;

			let langs = new Set();
			let group_names = new Set();
			data.chapters.forEach(chp => {
				Object.entries(chp.groups).forEach(([k, v]) => {
					group_names.add(k);
				});
				langs.add(chp.language);
			});

			const comp = (a, b) => {
				var ai;
				var bi;
				try {
					ai = parseFloat(a);
				} catch (e) {}
				try {
					bi = parseFloat(b);
				} catch (e) {}
				if (typeof ai === 'undefined') return -1;
				if (typeof bi === 'undefined') return 1;
				if (ai < bi) return 1;
				if (ai > bi) return -1;
				return 0;
			};

			langs = [...langs].sort();
			group_names = [...group_names].sort();

			langs.unshift('All');
			group_names.unshift('All');

			$('select#lang-select').append(langs.map(e => `<option>${e}</option>`).join(''));
			$('select#group-select').append(group_names.map(e => `<option>${e}</option>`).join(''));

			$('#filter-form').removeAttr('hidden');

			buildTable();
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to get manga info. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		})
		.always(() => {
			toggleSpinner();
		});
};
const parseRange = str => {
	const regex = /^[\t ]*(?:(?:(<|<=|>|>=)[\t ]*([0-9]+))|(?:([0-9]+))|(?:([0-9]+)[\t ]*-[\t ]*([0-9]+))|(?:[\t ]*))[\t ]*$/m;
	const matches = str.match(regex);
	var num;

	if (!matches) {
		alert('danger', `Failed to parse filter input ${str}`);
		return [null, null];
	} else if (typeof matches[1] !== 'undefined' && typeof matches[2] !== 'undefined') {
		// e.g., <= 30
		num = parseInt(matches[2]);
		if (isNaN(num)) {
			alert('danger', `Failed to parse filter input ${str}`);
			return [null, null];
		}
		switch (matches[1]) {
			case '<':
				return [null, num - 1];
			case '<=':
				return [null, num];
			case '>':
				return [num + 1, null];
			case '>=':
				return [num, null];
		}
	} else if (typeof matches[3] !== 'undefined') {
		// a single number
		num = parseInt(matches[3]);
		if (isNaN(num)) {
			alert('danger', `Failed to parse filter input ${str}`);
			return [null, null];
		}
		return [num, num];
	} else if (typeof matches[4] !== 'undefined' && typeof matches[5] !== 'undefined') {
		// e.g., 10 - 23
		num = parseInt(matches[4]);
		const n2 = parseInt(matches[5]);
		if (isNaN(num) || isNaN(n2) || num > n2) {
			alert('danger', `Failed to parse filter input ${str}`);
			return [null, null];
		}
		return [num, n2];
	} else {
		// empty or space only
		return [null, null];
	}
};
const getFilters = () => {
	const filters = {};
	$('.uk-select').each((i, ele) => {
		const id = $(ele).attr('id');
		const by = id.split('-')[0];
		const choice = $(ele).val();
		filters[by] = choice;
	});
	filters.volume = parseRange($('#volume-range').val());
	filters.chapter = parseRange($('#chapter-range').val());
	return filters;
};
const buildTable = () => {
	$('table').attr('hidden', '');
	$('#selection-controls').attr('hidden', '');
	$('#filter-notification').attr('hidden', '');
	console.log('rebuilding table');
	const filters = getFilters();
	console.log('filters:', filters);
	var chapters = globalChapters.slice();
	Object.entries(filters).forEach(([k, v]) => {
		if (v === 'All') return;
		if (k === 'group') {
			chapters = chapters.filter(c => {
				unescaped_groups = Object.entries(c.groups).map(([g, id]) => unescapeHTML(g));
				return unescaped_groups.indexOf(v) >= 0;
			});
			return;
		}
		if (k === 'lang') {
			chapters = chapters.filter(c => c.language === v);
			return;
		}
		const lb = parseFloat(v[0]);
		const ub = parseFloat(v[1]);
		if (isNaN(lb) && isNaN(ub)) return;
		chapters = chapters.filter(c => {
			const val = parseFloat(c[k]);
			if (isNaN(val)) return false;
			if (isNaN(lb))
				return val <= ub;
			else if (isNaN(ub))
				return val >= lb;
			else
				return val >= lb && val <= ub;
		});
	});
	console.log('filtered chapters:', chapters);
	$('#count-text').text(`${chapters.length} chapters found`);

	const chaptersLimit = 1000;
	if (chapters.length > chaptersLimit) {
		$('#filter-notification').text(`Mango can only list ${chaptersLimit} chapters, but we found ${chapters.length} chapters in this manga. Please use the filter options above to narrow down your search.`);
		$('#filter-notification').removeAttr('hidden');
		return;
	}

	const inner = chapters.map(chp => {
		const group_str = Object.entries(chp.groups).map(([k, v]) => {
			return `<a href="${baseURL }/group/${v}">${k}</a>`;
		}).join(' | ');
		const dark = loadTheme() === 'dark' ? 'dark' : '';
		return `<tr class="ui-widget-content ${dark}">
						<td><a href="${baseURL}/chapter/${chp.id}">${chp.id}</a></td>
						<td>${chp.title}</td>
						<td>${chp.language}</td>
						<td>${group_str}</td>
						<td>${chp.volume}</td>
						<td>${chp.chapter}</td>
						<td>${moment.unix(chp.time).fromNow()}</td>
					</tr>`;
	}).join('');
	const tbody = `<tbody id="selectable">${inner}</tbody>`;
	$('tbody').remove();
	$('table').append(tbody);
	$('table').removeAttr('hidden');
	$("#selectable").selectable({
		filter: 'tr'
	});
	$('#selection-controls').removeAttr('hidden');
};

const unescapeHTML = (str) => {
	var elt = document.createElement("span");
	elt.innerHTML = str;
	return elt.innerText;
};
