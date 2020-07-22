$(() => {
	$('#search-input').keypress(event => {
		if (event.which === 13) {
			search();
		}
	});
});

let searching = false;
const search = () => {
	if (searching)
		return;

	const query = $('#search-input').val();
	$.ajax({
			type: 'POST',
			url: base_url + 'api/admin/plugin/search',
			data: JSON.stringify({
				query: query,
				plugin: plugin
			}),
			contentType: "application/json",
			dataType: 'json'
		})
		.done(data => {
			console.log(data);
			if (data.error) {
				alert('danger', `Search failed. Error: ${data.error}`);
				return;
			}
		})
		.fail((jqXHR, status) => {
			alert('danger', `Search failed. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		})
		.always(() => {});
};
