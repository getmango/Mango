function showModal(title, zipPath, pages, percentage, title, entry) {
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

	$('#beginning-btn').attr('href', '/reader/' + title + '/' + entry + '/1');
	$('#continue-btn').attr('href', '/reader/' + title + '/' + entry);

	$('#read-btn').click(function(){
		updateProgress(title, entry, pages);
	});
	$('#unread-btn').click(function(){
		updateProgress(title, entry, 0);
	});

	UIkit.modal($('#modal')).show();
}
function updateProgress(title, entry, page) {
	$.post('/api/progress/' + title + '/' + entry + '/' + page, function(data) {
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
