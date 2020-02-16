$(function(){
	var target = '/admin/user/edit';
	if (username) target += username;
	$('form').attr('action', target);

	function alert(level, text) {
		hideAlert();
		var html = '<div class="uk-alert-' + level + '" uk-alert><a class="uk-alert-close" uk-close></a><p>' + text + '</p></div>';
		$('#alert').append(html);
	}
	function hideAlert() {
		$('#alert').empty();
	}

	if (error) alert('danger', error);
});
