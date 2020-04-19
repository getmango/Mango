function showModal(encodedPath, pages, percentage, encodedeTitle, encodedEntryTitle, titleID, entryID) {
	const zipPath = decodeURIComponent(encodedPath);
	const title = decodeURIComponent(encodedeTitle);
	const entry = decodeURIComponent(encodedEntryTitle);
	$('#modal button, #modal a').each(function(){
		$(this).removeAttr('hidden');
	});
	if (percentage === 0) {
		$('#continue-btn').attr('hidden', '');
		$('#unread-btn').attr('hidden', '');
	}
	else {
		$('#continue-btn').text('Continue from ' + percentage + '%');
	}
	if (percentage === 100) {
		$('#read-btn').attr('hidden', '');
	}
	$('#modal-title').find('span').text(entry);
	$('#modal-title').next().attr('data-id', titleID);
	$('#modal-title').next().attr('data-entry-id', entryID);
	$('#modal-title').next().find('.title-rename-field').val(entry);
	$('#path-text').text(zipPath);
	$('#pages-text').text(pages + ' pages');

	$('#beginning-btn').attr('href', '/reader/' + titleID + '/' + entryID + '/1');
	$('#continue-btn').attr('href', '/reader/' + titleID + '/' + entryID);

	$('#read-btn').click(function(){
		updateProgress(titleID, entryID, pages);
	});
	$('#unread-btn').click(function(){
		updateProgress(titleID, entryID, 0);
	});

	$('.uk-modal-title.break-word > a').attr('onclick', `edit("${entryID}")`);

	UIkit.modal($('#modal')).show();
	styleModal();
}

const updateProgress = (tid, eid, page) => {
	let url = `/api/progress/${tid}/${page}`
	const query = $.param({entry: eid});
	if (eid)
		url += `?${query}`;
	$.post(url, (data) => {
		if (data.success) {
			location.reload();
		}
		else {
			error = data.error;
			alert('danger', error);
		}
	});
};

const renameSubmit = (name, eid) => {
	const upload = $('.upload-field');
	const titleId = upload.attr('data-title-id');

	console.log(name);

	if (name.length === 0) {
		alert('danger', 'The display name should not be empty');
		return;
	}

	const query = $.param({ entry: eid });
	let url = `/api/admin/display_name/${titleId}/${name}`;
	if (eid)
		url += `?${query}`;

	$.ajax({
		type: 'POST',
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

const edit = (eid) => {
	const cover = $('#edit-modal #cover');
	let url = cover.attr('data-title-cover');
	let displayName = $('h2.uk-title > span').text();

	if (eid) {
		const item = $(`#${eid}`);
		url = item.find('img').attr('data-src');
		displayName = item.find('.uk-card-title').attr('data-title');
		$('#title-progress-control').attr('hidden', '');
	}
	else {
		$('#title-progress-control').removeAttr('hidden');
	}

	cover.attr('data-src', url);

	const displayNameField = $('#display-name-field');
	displayNameField.attr('value', displayName);
	displayNameField.keyup(event => {
		if (event.keyCode === 13) {
			renameSubmit(displayNameField.val(), eid);
		}
	});
	displayNameField.siblings('a.uk-form-icon').click(() => {
		renameSubmit(displayNameField.val(), eid);
	});

	setupUpload(eid);

	UIkit.modal($('#edit-modal')).show();
	styleModal();
};

const setupUpload = (eid) => {
	const upload = $('.upload-field');
	const bar = $('#upload-progress').get(0);
	const titleId = upload.attr('data-title-id');
	const queryObj = {title: titleId};
	if (eid)
		queryObj['entry'] = eid;
	const query = $.param(queryObj);
	const url = `/api/admin/upload/cover?${query}`;
	console.log(url);
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
