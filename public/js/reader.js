let lastSavedPage = page;
let items = [];
let longPages = false;

$(() => {
	getPages();

	$('#page-select').change(() => {
		const p = parseInt($('#page-select').val());
		toPage(p);
	});
});

/**
 * Set an alpine.js property
 *
 * @function setProp
 * @param {string} key - Key of the data property
 * @param {*} prop - The data property
 */
const setProp = (key, prop) => {
	$('#root').get(0).__x.$data[key] = prop;
};

/**
 * Get dimension of the pages in the entry from the API and update the view
 */
const getPages = () => {
	$.get(`${base_url}api/dimensions/${tid}/${eid}`)
		.then(data => {
			if (!data.success && data.error)
				throw new Error(resp.error);
			const dimensions = data.dimensions;

			items = dimensions.map((d, i) => {
				return {
					id: i + 1,
					url: `${base_url}api/page/${tid}/${eid}/${i+1}`,
					width: d.width,
					height: d.height
				};
			});

			const avgRatio = items.reduce((acc, cur) => {
				return acc + cur.height / cur.width
			}, 0) / items.length;

			console.log(avgRatio);
			longPages = avgRatio > 2;

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

/**
 * Jump to a specific page
 *
 * @function toPage
 * @param {number} idx - One-based index of the page
 */
const toPage = (idx) => {
	$(`#${idx}`).get(0).scrollIntoView(true);
	UIkit.modal($('#modal-sections')).hide();
};

/**
 * Check if a page exists every 100ms. If so, invoke the callback function.
 *
 * @function waitForPage
 * @param {number} idx - One-based index of the page
 * @param {function} cb - Callback function
 */
const waitForPage = (idx, cb) => {
	if ($(`#${idx}`).length > 0) return cb();
	setTimeout(() => {
		waitForPage(idx, cb)
	}, 100);
};

/**
 * Show the control modal
 *
 * @function showControl
 * @param {object} event - The onclick event that triggers the function
 */
const showControl = (event) => {
	const idx = parseInt($(event.currentTarget).attr('id'));
	const pageCount = $('#page-select > option').length;
	const progressText = `Progress: ${idx}/${pageCount} (${(idx/pageCount * 100).toFixed(1)}%)`;
	$('#progress-label').text(progressText);
	$('#page-select').val(idx);
	UIkit.modal($('#modal-sections')).show();
}

/**
 * Redirect to a URL
 *
 * @function redirect
 * @param {string} url - The target URL
 */
const redirect = (url) => {
	window.location.replace(url);
}

/**
 * Replace the address bar history and save th ereading progress if necessary
 *
 * @function replaceHistory
 * @param {number} idx - One-based index of the current page
 */
const replaceHistory = (idx) => {
	const ary = window.location.pathname.split('/');
	ary[ary.length - 1] = idx;
	ary.shift(); // remove leading `/`
	ary.unshift(window.location.origin);
	const url = ary.join('/');
	saveProgress(idx);
	history.replaceState(null, "", url);
}

/**
 * Set up the scroll handler that calls `replaceHistory` when an image
 * 		enters the view port
 *
 * @function setupScroller
 */
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

/**
 * Update the backend reading progress if:
 * 		1) the current page is more than five pages away from the last 
 * 			saved page, or
 * 		2) the average height/width ratio of the pages is over 2, or
 * 		3) the current page is the first page, or
 * 		4) the current page is the last page
 *
 * @function saveProgress
 * @param {number} idx - One-based index of the page
 * @param {function} cb - Callback
 */
const saveProgress = (idx, cb) => {
	idx = parseInt(idx);
	if (Math.abs(idx - lastSavedPage) >= 5 ||
		longPages ||
		idx === 1 || idx === items.length
	) {
		lastSavedPage = idx;
		console.log('saving progress', idx);

		const url = `${base_url}api/progress/${tid}/${idx}?${$.param({entry: eid})}`;
		$.post(url)
			.then(data => {
				if (data.error) throw new Error(data.error);
				if (cb) cb();
			})
			.catch(e => {
				console.error(e);
				alert('danger', e);
			});
	}
};

/**
 * Mark progress to 100% and redirect to the next entry
 * 	Used as the onclick handler for the "Next Entry" button
 *
 * @function nextEntry
 * @param {string} nextUrl - URL of the next entry
 */
const nextEntry = (nextUrl) => {
	saveProgress(items.length, () => {
		redirect(nextUrl);
	});
};
