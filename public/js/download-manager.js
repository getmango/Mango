/**
 * Get the current queue and update the view
 *
 * @function load
 */
const load = () => {
	try {
		setProp('loading', true);
	} catch {}
	$.ajax({
			type: 'GET',
			url: base_url + 'api/admin/mangadex/queue',
			dataType: 'json'
		})
		.done(data => {
			if (!data.success && data.error) {
				alert('danger', `Failed to fetch download queue. Error: ${data.error}`);
				return;
			}
			setProp('jobs', data.jobs);
			setProp('paused', data.paused);
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to fetch download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		})
		.always(() => {
			setProp('loading', false);
		});
};

/**
 * Perform an action on either a specific job or the entire queue
 *
 * @function jobAction
 * @param {string} action - The action to perform. Should be either 'delete' or 'retry'
 * @param {string?} id - (Optional) A job ID. When omitted, apply the action to the queue
 */
const jobAction = (action, id) => {
	let url = `${base_url}api/admin/mangadex/queue/${action}`;
	if (id !== undefined)
		url += '?' + $.param({
			id: id
		});
	console.log(url);
	$.ajax({
			type: 'POST',
			url: url,
			dataType: 'json'
		})
		.done(data => {
			if (!data.success && data.error) {
				alert('danger', `Failed to ${action} job from download queue. Error: ${data.error}`);
				return;
			}
			load();
		})
		.fail((jqXHR, status) => {
			alert('danger', `Failed to ${action} job from download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
		});
};

/**
 * Pause/resume the download
 *
 * @function toggle
 */
const toggle = () => {
	setProp('toggling', true);
	const action = getProp('paused') ? 'resume' : 'pause';
	const url = `${base_url}api/admin/mangadex/queue/${action}`;
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
			setProp('toggling', false);
		});
};

/**
 * Get the uk-label class name for a given job status
 *
 * @function statusClass
 * @param {string} status - The job status
 * @return {string} The class name string
 */
const statusClass = status => {
	let cls = 'label ';
	switch (status) {
		case 'Pending':
			cls += 'label-pending';
			break;
		case 'Completed':
			cls += 'label-success';
			break;
		case 'Error':
			cls += 'label-danger';
			break;
		case 'MissingPages':
			cls += 'label-warning';
			break;
	}
	return cls;
};

$(() => {
	const ws = new WebSocket(`ws://${location.host}/api/admin/mangadex/queue`);
	ws.onmessage = event => {
		const data = JSON.parse(event.data);
		setProp('jobs', data.jobs);
		setProp('paused', data.paused);
	};
	ws.onerror = err => {
		alert('danger', `Socket connection failed. Error: ${err}`);
	};
	ws.onclose = err => {
		alert('danger', 'Socket connection failed');
	};
});
