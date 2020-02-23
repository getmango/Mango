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
	$('#modal-title').text(title);
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
function alert(level, text) {
	hideAlert();
	var html = '<div class="uk-alert-' + level + '" uk-alert><a class="uk-alert-close" uk-close></a><p>' + text + '</p></div>';
	$('#alert').append(html);
}
function hideAlert() {
	$('#alert').empty();
}
