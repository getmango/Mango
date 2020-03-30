const truncate = () => {
	$('.acard .uk-card-title').each((i, e) => {
		new Dotdotdot(e, {
			height: 120,
			truncate: 'letter'
		});
	});
};

truncate();
