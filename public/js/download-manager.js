$(() => {
	load();
});
const load = () => {
	$.ajax({
		type: 'GET',
		url: '/api/admin/mangadex/queue',
		dataType: 'json'
	})
	.done(data => {
		console.log(data);
		const rows = data.map(obj => {
			var cls = 'uk-label ';
			if (obj.status === 'Completed')
				cls += 'uk-label-success';
			if (obj.status === 'Error')
				cls += 'uk-label-danger';
			if (obj.status === 'MissingPages')
				cls += 'uk-label-warning';

			const statusSpan = `<span class="${cls}">${obj.status}</span>`;
			return `<tr>
				<td><a href="${baseURL}/chapter/${obj.id}">${obj.title}</a></td>
				<td><a href="${baseURL}/manga/${obj.manga_id}">${obj.manga_title}</a></td>
				<td>${obj.success_count}/${obj.pages}</td>
				<td>${moment(obj.time).fromNow()}</td>
				<td>${statusSpan}</td>
				<td>
					<a href="#" uk-icon="trash"></a>
					<a href="#" uk-icon="info"></a>
				</td>
				</tr>`;
		});

		const tbody = `<tbody>${rows.join('')}</tbody>`;
		$('tbody').remove();
		$('table').append(tbody);
	})
	.fail((jqXHR, status) => {
		alert('danger', `Failed to fetch download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
	});
};
