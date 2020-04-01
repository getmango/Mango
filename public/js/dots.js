const truncate = () => {
	$('.acard .uk-card-title').each((i, e) => {
		$(e).dotdotdot({
			truncate: 'letter'
		});
	});
};

$(() => {
	truncate();
});
