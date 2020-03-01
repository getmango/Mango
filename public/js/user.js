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
