$(() => {
	setupAcard();
});

const setupAcard = () => {
	$('.acard.is_entry').click((e) => {
		if ($(e.target).hasClass('no-modal')) return;
		const card = $(e.target).closest('.acard');

		showModal(
			$(card).attr('data-encoded-path'),
			parseInt($(card).attr('data-pages')),
			parseFloat($(card).attr('data-progress')),
			$(card).attr('data-encoded-book-title'),
			$(card).attr('data-encoded-title'),
			$(card).attr('data-book-id'),
			$(card).attr('data-id')
		);
	});
};

function showModal(encodedPath, pages, percentage, encodedeTitle, encodedEntryTitle, titleID, entryID) {
	const zipPath = decodeURIComponent(encodedPath);
	const title = decodeURIComponent(encodedeTitle);
	const entry = decodeURIComponent(encodedEntryTitle);
	$('#modal button, #modal a').each(function() {
		$(this).removeAttr('hidden');
	});
	if (percentage === 0) {
		$('#continue-btn').attr('hidden', '');
		$('#unread-btn').attr('hidden', '');
	} else if (percentage === 100) {
		$('#read-btn').attr('hidden', '');
		$('#continue-btn').attr('hidden', '');
	} else {
		$('#continue-btn').text('Continue from ' + percentage + '%');
	}

	$('#modal-entry-title').find('span').text(entry);
	$('#modal-entry-title').next().attr('data-id', titleID);
	$('#modal-entry-title').next().attr('data-entry-id', entryID);
	$('#modal-entry-title').next().find('.title-rename-field').val(entry);
	$('#path-text').text(zipPath);
	$('#pages-text').text(pages + ' pages');

	$('#beginning-btn').attr('href', `${base_url}reader/${titleID}/${entryID}/1`);
	$('#continue-btn').attr('href', `${base_url}reader/${titleID}/${entryID}`);

	$('#read-btn').click(function() {
		updateProgress(titleID, entryID, pages);
	});
	$('#unread-btn').click(function() {
		updateProgress(titleID, entryID, 0);
	});

	$('#modal-edit-btn').attr('onclick', `edit("${entryID}")`);

	$('#modal-download-btn').attr('href', `${base_url}api/download/${titleID}/${entryID}`);

	UIkit.modal($('#modal')).show();
}

UIkit.util.on(document, 'hidden', '#modal', () => {
	$('#read-btn').off('click');
	$('#unread-btn').off('click');
});

const updateProgress = (tid, eid, page) => {
	let url = `${base_url}api/progress/${tid}/${page}`
	const query = $.param({
		eid: eid
	});
	if (eid)
		url += `?${query}`;

	$.ajax({
			method: 'PUT',
			url: url,
			dataType: 'json'
		})
		.done(data => {
			if (data.success) {
				location.reload();
			} else {
				error = data.error;
				alert('danger', error);
			}
		})
		.fail((jqXHR, status) => {
			alert('danger', `Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		});
};

const renameSubmit = (name, eid) => {
	const upload = $('.upload-field');
	const titleId = upload.attr('data-title-id');

	if (name.length === 0) {
		alert('danger', 'The display name should not be empty');
		return;
	}

	const query = $.param({
		eid: eid
	});
	let url = `${base_url}api/admin/display_name/${titleId}/${name}`;
	if (eid)
		url += `?${query}`;

	$.ajax({
			type: 'PUT',
			url: url,
			contentType: "application/json",
			dataType: 'json'
		})
		.done(data => {
			if (data.error) {
				alert('danger', `Failed to update display name. Error: ${data.error}`);
				return;
			}
			location.reload();
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to update display name. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		});
};

const renameSortNameSubmit = (name, eid) => {
	const upload = $('.upload-field');
	const titleId = upload.attr('data-title-id');

	const params = {};
	if (eid) params.eid = eid;
	if (name) params.name = name;
	const query = $.param(params);
	let url = `${base_url}api/admin/sort_title/${titleId}?${query}`;

	$.ajax({
			type: 'PUT',
			url,
			contentType: 'application/json',
			dataType: 'json'
		})
		.done(data => {
			if (data.error) {
				alert('danger', `Failed to update sort title. Error: ${data.error}`);
				return;
			}
			location.reload();
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to update sort title. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		});
};

const edit = (eid) => {
	const cover = $('#edit-modal #cover');
	let url = cover.attr('data-title-cover');
	let displayName = $('h2.uk-title > span').text();
	let fileTitle = $('h2.uk-title').attr('data-file-title');
	let sortTitle = $('h2.uk-title').attr('data-sort-title');

	if (eid) {
		const item = $(`#${eid}`);
		url = item.find('img').attr('data-src');
		displayName = item.find('.uk-card-title').attr('data-title');
		fileTitle = item.find('.uk-card-title').attr('data-file-title');
		sortTitle = item.find('.uk-card-title').attr('data-sort-title');
		$('#title-progress-control').attr('hidden', '');
	} else {
		$('#title-progress-control').removeAttr('hidden');
	}

	cover.attr('data-src', url);

	const displayNameField = $('#display-name-field');
	displayNameField.attr('value', displayName);
	displayNameField.attr('placeholder', fileTitle);
	displayNameField.keyup(event => {
		if (event.keyCode === 13) {
			renameSubmit(displayNameField.val() || fileTitle, eid);
		}
	});
	displayNameField.siblings('a.uk-form-icon').click(() => {
		renameSubmit(displayNameField.val() || fileTitle, eid);
	});

	const sortTitleField = $('#sort-title-field');
	sortTitleField.val(sortTitle);
	sortTitleField.attr('placeholder', fileTitle);
	sortTitleField.keyup(event => {
		if (event.keyCode === 13) {
			renameSortNameSubmit(sortTitleField.val(), eid);
		}
	});
	sortTitleField.siblings('a.uk-form-icon').click(() => {
		renameSortNameSubmit(sortTitleField.val(), eid);
	});

	setupUpload(eid);

	UIkit.modal($('#edit-modal')).show();
};

UIkit.util.on(document, 'hidden', '#edit-modal', () => {
	const displayNameField = $('#display-name-field');
	displayNameField.off('keyup');
	displayNameField.off('click');

	const sortTitleField = $('#sort-title-field');
	sortTitleField.off('keyup');
	sortTitleField.off('click');
});

const setupUpload = (eid) => {
	const upload = $('.upload-field');
	const bar = $('#upload-progress').get(0);
	const titleId = upload.attr('data-title-id');
	const queryObj = {
		tid: titleId
	};
	if (eid)
		queryObj['eid'] = eid;
	const query = $.param(queryObj);
	const url = `${base_url}api/admin/upload/cover?${query}`;
	UIkit.upload('.upload-field', {
		url: url,
		name: 'file',
		error: (e) => {
			alert('danger', `Failed to upload cover image: ${e.toString()}`);
		},
		loadStart: (e) => {
			$(bar).removeAttr('hidden');
			bar.max = e.total;
			bar.value = e.loaded;
		},
		progress: (e) => {
			bar.max = e.total;
			bar.value = e.loaded;
		},
		loadEnd: (e) => {
			bar.max = e.total;
			bar.value = e.loaded;
		},
		completeAll: () => {
			$(bar).attr('hidden', '');
			location.reload();
		}
	});
};

const deselectAll = () => {
	$('.item .uk-card').each((i, e) => {
		const data = e.__x.$data;
		data['selected'] = false;
	});
	$('#select-bar')[0].__x.$data['count'] = 0;
};

const selectAll = () => {
	let count = 0;
	$('.item .uk-card').each((i, e) => {
		const data = e.__x.$data;
		if (!data['disabled']) {
			data['selected'] = true;
			count++;
		}
	});
	$('#select-bar')[0].__x.$data['count'] = count;
};

const selectedIDs = () => {
	const ary = [];
	$('.item .uk-card').each((i, e) => {
		const data = e.__x.$data;
		if (!data['disabled'] && data['selected']) {
			const item = $(e).closest('.item');
			ary.push($(item).attr('id'));
		}
	});
	return ary;
};

const bulkProgress = (action, el) => {
	const tid = $(el).attr('data-id');
	const ids = selectedIDs();
	const url = `${base_url}api/bulk_progress/${action}/${tid}`;
	$.ajax({
			type: 'PUT',
			url: url,
			contentType: "application/json",
			dataType: 'json',
			data: JSON.stringify({
				ids: ids
			})
		})
		.done(data => {
			if (data.error) {
				alert('danger', `Failed to mark entries as ${action}. Error: ${data.error}`);
				return;
			}
			location.reload();
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to mark entries as ${action}. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		})
		.always(() => {
			deselectAll();
		});
};

const tagsComponent = () => {
	return {
		isAdmin: false,
		tags: [],
		tid: $('.upload-field').attr('data-title-id'),
		loading: true,

		load(admin) {
			this.isAdmin = admin;

			$('.tag-select').select2({
				tags: true,
				placeholder: this.isAdmin ? 'Tag the title' : 'No tags found',
				disabled: !this.isAdmin,
				templateSelection(state) {
					const a = document.createElement('a');
					a.setAttribute('href', `${base_url}tags/${encodeURIComponent(state.text)}`);
					a.setAttribute('class', 'uk-link-reset');
					a.onclick = event => {
						event.stopPropagation();
					};
					a.innerText = state.text;
					return a;
				}
			});

			this.request(`${base_url}api/tags`, 'GET', (data) => {
				const allTags = data.tags;
				const url = `${base_url}api/tags/${this.tid}`;
				this.request(url, 'GET', data => {
					this.tags = data.tags;
					allTags.forEach(t => {
						const op = new Option(t, t, false, this.tags.indexOf(t) >= 0);
						$('.tag-select').append(op);
					});
					$('.tag-select').on('select2:select', e => {
						this.onAdd(e);
					});
					$('.tag-select').on('select2:unselect', e => {
						this.onDelete(e);
					});
					$('.tag-select').on('change', () => {
						this.onChange();
					});
					$('.tag-select').trigger('change');
					this.loading = false;
				});
			});
		},
		onChange() {
			this.tags = $('.tag-select').select2('data').map(o => o.text);
		},
		onAdd(event) {
			const tag = event.params.data.text;
			const url = `${base_url}api/admin/tags/${this.tid}/${encodeURIComponent(tag)}`;
			this.request(url, 'PUT');
		},
		onDelete(event) {
			const tag = event.params.data.text;
			const url = `${base_url}api/admin/tags/${this.tid}/${encodeURIComponent(tag)}`;
			this.request(url, 'DELETE');
		},
		request(url, method, cb) {
			$.ajax({
					url: url,
					method: method,
					dataType: 'json'
				})
				.done(data => {
					if (data.success) {
						if (cb) cb(data);
					} else {
						alert('danger', data.error);
					}
				})
				.fail((jqXHR, status) => {
					alert('danger', `Error: [${jqXHR.status}] ${jqXHR.statusText}`);
				});
		}
	};
};
