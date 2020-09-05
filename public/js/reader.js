$(() => {
	getPages();

	$('#page-select').change(() => {
		const p = parseInt($('#page-select').val());
		toPage(p);
	});
});

const getPages = () => {
	$.get(`${base_url}api/dimensions/${tid}/${eid}`)
		.then(data => {
			if (!data.success && data.error)
				throw new Error(resp.error);
			const dimensions = data.dimensions;

			const items = dimensions.map((d, i) => {
				return {
					id: i + 1,
					url: `${base_url}api/page/${tid}/${eid}/${i+1}`,
					width: d.width,
					height: d.height
				};
			});

			setProp('items', items);
			setProp('loading', false);

			waitForPage(items.length, () => {
				toPage(page);
				setupScroller();
			});
		})
		.catch(e => {
			const errMsg = `Failed to get the page dimensions. ${e}`;
			console.error(e);
			setProp('alertClass', 'uk-alert-danger');
			setProp('msg', errMsg);
		})
};

const toPage = (idx) => {
	$(`#${idx}`).get(0).scrollIntoView(true);
	UIkit.modal($('#modal-sections')).hide();
};

const waitForPage = (idx, cb) => {
	if ($(`#${idx}`).length > 0) return cb();
	setTimeout(() => {
		waitForPage(idx, cb)
	}, 100);
};

const setProp = (key, prop) => {
	$('#root').get(0).__x.$data[key] = prop;
};

const showControl = (event) => {
	const idx = parseInt($(event.currentTarget).attr('id'));
	const pageCount = $('#page-select > option').length;
	const progressText = `Progress: ${idx}/${pageCount} (${(idx/pageCount * 100).toFixed(1)}%)`;
	$('#progress-label').text(progressText);
	$('#page-select').val(idx);
	UIkit.modal($('#modal-sections')).show();
}

const redirect = (url) => {
	window.location.replace(url);
}

const replaceHistory = (idx) => {
	const ary = window.location.pathname.split('/');
	ary[ary.length - 1] = idx;
	ary.shift(); // remove leading `/`
	ary.unshift(window.location.origin);
	const url = ary.join('/');
	saveProgress(idx);
	history.replaceState(null, "", url);
}

const setupScroller = () => {
	$('#root img').each((idx, el) => {
		$(el).on('inview', (event, inView) => {
			if (inView) {
				const current = $(event.currentTarget).attr('id');
				replaceHistory(current);
			}
		});
	});
};

let lastSavedPage = page;
const saveProgress = (idx) => {
	if (Math.abs(idx - lastSavedPage) < 5) return;
	lastSavedPage = idx;

	const url = `${base_url}api/progress/${tid}/${idx}?${$.param({entry: eid})}`;
	$.post(url)
		.then(data => {
			if (data.error) throw new Error(data.error);
		})
		.catch(e => {
			console.error(e);
			alert('danger', e);
		});
};
