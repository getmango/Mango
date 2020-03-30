const getTheme = () => {
	var theme = localStorage.getItem('theme');
	if (!theme) theme = 'light';
	return theme;
};

const saveTheme = theme => {
	localStorage.setItem('theme', theme);
};

const toggleTheme = () => {
	const theme = getTheme();
	const newTheme = theme === 'dark' ? 'light' : 'dark';
	setTheme(newTheme);
	saveTheme(newTheme);
};

const setTheme = themeStr => {
	if (themeStr === 'dark') {
		$('html').css('background', 'rgb(20, 20, 20)');
		$('body').addClass('uk-light');
		$('.uk-card').addClass('uk-card-secondary');
		$('.uk-card').removeClass('uk-card-default');
		$('.ui-widget-content').addClass('dark');
	}
	else {
		$('html').css('background', '');
		$('body').removeClass('uk-light');
		$('.uk-card').removeClass('uk-card-secondary');
		$('.uk-card').addClass('uk-card-default');
		$('.ui-widget-content').removeClass('dark');
	}
};

const styleModal = () => {
	const color = getTheme() === 'dark' ? '#222' : '';
	$('.uk-modal-header').css('background', color);
	$('.uk-modal-body').css('background', color);
	$('.uk-modal-footer').css('background', color);
};

// do it before document is ready to prevent the initial flash of white
setTheme(getTheme());
