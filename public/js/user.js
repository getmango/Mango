function alert(level, text) {
	hideAlert();
	var html = '<div class="uk-alert-' + level + '" uk-alert><a class="uk-alert-close" uk-close></a><p>' + text + '</p></div>';
	$('#alert').append(html);
}
function hideAlert() {
	$('#alert').empty();
}
function remove(username) {
	$.post('/api/admin/user/delete/' + username, function(data) {
		if (data.success) {
			location.reload();
		}
		else {
			error = data.error;
			alert('danger', error);
		}
	});
}
