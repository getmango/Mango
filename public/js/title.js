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

	UIkit.modal($('#modal')).show();
	styleModal();
}
function updateProgress(titleID, entryID, page) {
	$.post('/api/progress/' + titleID + '/' + entryID + '/' + page, function(data) {
		if (data.success) {
			location.reload();
		}
		else {
			error = data.error;
			alert('danger', error);
		}
	});
}

const rename = ele => {
	const h2 = $(ele).parent();

	$(h2).attr('hidden', true);
	$(h2).next().removeAttr('hidden');
};

const renameSubmit = ele => {
	const group = $(ele).closest('.title-rename');
	const id = $(group).attr('data-id');
	const eid = $(group).attr('data-entry-id');
	const name = $(ele).next().val();

	console.log(name);

	$(group).attr('hidden', true);
	$(group).prev().removeAttr('hidden');

	if (name.length === 0) {
		alert('danger', 'The display name should not be empty');
		return;
	}

	$(group).prev().find('span').text(name);

	const query = $.param({ entry: eid });
	let url = `/api/admin/display_name/${id}/${name}`;
	if (eid)
		url += `?${query}`;

	$.ajax({
		type: 'POST',
		url: url,
		contentType: "application/json",
		dataType: 'json'
	})
	.done(data => {
		console.log(data);
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

$(() => {
	$('.uk-input.title-rename-field').keyup(event => {
		if (event.keyCode === 13) {
			renameSubmit($(event.currentTarget).prev());
		}
	});
});
