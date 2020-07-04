$(() => {
	const sortItems = () => {
		const sort = $('#sort-select').find(':selected').attr('id');
		const ary = sort.split('-');
		const by = ary[0];
		const dir = ary[1];

		let items = $('.item');
		items.remove();

		const ctxAry = [];
		const keyRange = {};
		if (by === 'auto') {
			// intelligent sorting
			items.each((i, item) => {
				const name = $(item).find('.uk-card-title').text();
				const regex = /([^0-9\n\r\ ]*)[ ]*([0-9]*\.*[0-9]+)/g;

				const numbers = {};
				let match = regex.exec(name);
				while (match) {
					const key = match[1];
					const num = parseFloat(match[2]);
					numbers[key] = num;

					if (!keyRange[key]) {
						keyRange[key] = [num, num, 1];
					} else {
						keyRange[key][2] += 1;
						if (num < keyRange[key][0]) {
							keyRange[key][0] = num;
						} else if (num > keyRange[key][1]) {
							keyRange[key][1] = num;
						}
					}

					match = regex.exec(name);
				}
				ctxAry.push({
					index: i,
					numbers: numbers
				});
			});

			console.log(keyRange);

			const sortedKeys = Object.keys(keyRange).filter(k => {
				return keyRange[k][2] >= items.length / 2;
			});

			sortedKeys.sort((a, b) => {
				// sort by frequency of the key first
				if (keyRange[a][2] !== keyRange[b][2]) {
					return (keyRange[a][2] < keyRange[b][2]) ? 1 : -1;
				}
				// then sort by range of the key
				return ((keyRange[a][1] - keyRange[a][0]) < (keyRange[b][1] - keyRange[b][0])) ? 1 : -1;
			});

			console.log(sortedKeys);

			ctxAry.sort((a, b) => {
				for (let i = 0; i < sortedKeys.length; i++) {
					const key = sortedKeys[i];

					if (a.numbers[key] === undefined && b.numbers[key] === undefined)
						continue;
					if (a.numbers[key] === undefined)
						return 1;
					if (b.numbers[key] === undefined)
						return -1;
					if (a.numbers[key] === b.numbers[key])
						continue;
					return (a.numbers[key] > b.numbers[key]) ? 1 : -1;
				}
				return 0;
			});

			const sortedItems = [];
			ctxAry.forEach(ctx => {
				sortedItems.push(items[ctx.index]);
			});
			items = sortedItems;

			if (dir === 'down') {
				items.reverse();
			}
		} else {
			items.sort((a, b) => {
				var res;
				if (by === 'name')
					res = $(a).find('.uk-card-title').text() > $(b).find('.uk-card-title').text();
				else if (by === 'date')
					res = $(a).attr('data-mtime') > $(b).attr('data-mtime');
				else if (by === 'progress') {
					const ap = parseFloat($(a).attr('data-progress'));
					const bp = parseFloat($(b).attr('data-progress'));
					if (ap === bp)
						// if progress is the same, we compare by name
						res = $(a).find('.uk-card-title').text() > $(b).find('.uk-card-title').text();
					else
						res = ap > bp;
				}
				if (dir === 'up')
					return res ? 1 : -1;
				else
					return !res ? 1 : -1;
			});
		}
		$('#item-container').append(items);
		setupAcard();
	};

	$('#sort-select').change(() => {
		sortItems();
	});

	if ($('option#auto-up').length > 0)
		$('option#auto-up').attr('selected', '');
	else
		$('option#name-up').attr('selected', '');

	sortItems();
});
