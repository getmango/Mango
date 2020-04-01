const truncate = () => {
	$('.acard .uk-card-title').each((i, e) => {
		$(e).dotdotdot({
			truncate: 'letter',
			callback: (truncated) => {
				if (truncated) {
					$(e).attr('uk-tooltip', $(e).attr('data-title'));
				}
				else {
					$(e).removeAttr('uk-tooltip');
				}
			}
		});
	});
};

$(() => {
	truncate();
});
