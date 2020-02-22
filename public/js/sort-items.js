$(() => {
	$('option#name-up').attr('selected', '');
	$('#sort-select').change(() => {
		const sort = $('#sort-select').find(':selected').attr('id');
		const ary = sort.split('-');
		const by = ary[0];
		const dir = ary[1];

		const items = $('.item');
		items.remove();

		items.sort((a, b) => {
			var res;
			if (by === 'name')
				res = $(a).find('.uk-card-title').text() > $(b).find('.uk-card-title').text();
			else if (by === 'date')
				res = $(a).attr('data-mtime') > $(b).attr('data-mtime');
			else {
				const ap = $(a).attr('data-progress');
				const bp = $(b).attr('data-progress');
				if (ap === bp)
					// if progress is the same, we compare by name
					res = $(a).find('.uk-card-title').text() > $(b).find('.uk-card-title').text();
				else
					res = ap > bp;
			}
			if (dir === 'up')
				return res;
			else
				return !res;
		});
		var html = '';
		$('#item-container').append(items);
	});
});
