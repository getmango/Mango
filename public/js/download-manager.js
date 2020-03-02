$(() => {
	$('input.uk-checkbox').each((i, e) => {
		$(e).change(() => {
			loadConfig();
		});
	});
	loadConfig();
	load();

	const intervalMS = 5000;
	setTimeout(() => {
		setInterval(() => {
			if (globalConfig.autoRefresh !== true) return;
			load();
		}, intervalMS);
	}, intervalMS);
});
var globalConfig = {};
var loading = false;

const loadConfig = () => {
	globalConfig.autoRefresh = $('#auto-refresh').prop('checked');
};
const remove = (id) => {
	var url = '/api/admin/mangadex/queue/delete/';
	if (id !== undefined) {
		url += id;
	}
	$.ajax({
		type: 'POST',
		url: url,
		dataType: 'json'
	})
	.done(data => {
		if (!data.success && data.error) {
			alert('danger', `Failed to remove job from download queue. Error: ${data.error}`);
			return;
		}
		load();
	})
	.fail((jqXHR, status) => {
		alert('danger', `Failed to remove job from download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
	});
};
const refresh = (id) => {
	var url = '/api/admin/mangadex/queue/retry/';
	if (id !== undefined) {
		url += id;
	}
	$.ajax({
		type: 'POST',
		url: url,
		dataType: 'json'
	})
	.done(data => {
		if (!data.success && data.error) {
			alert('danger', `Failed to restart download job. Error: ${data.error}`);
			return;
		}
		load();
	})
	.fail((jqXHR, status) => {
		alert('danger', `Failed to restart download job. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
	});
};
const toggle = () => {
	$('#pause-resume-btn').attr('disabled', '');
	const paused = $('#pause-resume-btn').text() === 'Resume download';
	const action = paused ? 'resume' : 'pause';
	const url = `/api/admin/mangadex/queue/${action}`;
	$.ajax({
		type: 'POST',
		url: url,
		dataType: 'json'
	})
	.fail((jqXHR, status) => {
		alert('danger', `Failed to ${action} download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
	})
	.always(() => {
		load();
		$('#pause-resume-btn').removeAttr('disabled');
	});
};
const load = () => {
	if (loading) return;
	loading = true;
	console.log('fetching');
	$.ajax({
		type: 'GET',
		url: '/api/admin/mangadex/queue',
		dataType: 'json'
	})
	.done(data => {
		console.log(data);
		const btnText = data.paused ? "Resume download" : "Pause download";
		$('#pause-resume-btn').text(btnText);
		$('#pause-resume-btn').removeAttr('hidden');
		const rows = data.jobs.map(obj => {
			var cls = 'uk-label ';
			if (obj.status === 'Completed')
				cls += 'uk-label-success';
			if (obj.status === 'Error')
				cls += 'uk-label-danger';
			if (obj.status === 'MissingPages')
				cls += 'uk-label-warning';

			const info = obj.status_message.length > 0 ? '<span uk-icon="info"></span>' : '';
			const statusSpan = `<span class="${cls}">${obj.status} ${info}</span>`;
			const dropdown = obj.status_message.length > 0 ? `<div uk-dropdown>${obj.status_message}</div>` : '';
			const retryBtn = obj.status_message.length > 0 ? `<a onclick="refresh('${obj.id}')" uk-icon="refresh"></a>` : '';
			return `<tr id="chapter-${obj.id}">
				<td><a href="${baseURL}/chapter/${obj.id}">${obj.title}</a></td>
				<td><a href="${baseURL}/manga/${obj.manga_id}">${obj.manga_title}</a></td>
				<td>${obj.success_count}/${obj.pages}</td>
				<td>${moment(obj.time).fromNow()}</td>
				<td>${statusSpan} ${dropdown}</td>
				<td>
					<a onclick="remove('${obj.id}')" uk-icon="trash"></a>
					${retryBtn}
				</td>
				</tr>`;
		});

		const tbody = `<tbody>${rows.join('')}</tbody>`;
		$('tbody').remove();
		$('table').append(tbody);
	})
	.fail((jqXHR, status) => {
		alert('danger', `Failed to fetch download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
	})
	.always(() => {
		loading = false;
	});
};
