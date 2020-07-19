// https://flaviocopes.com/javascript-detect-dark-mode/
const preferDarkMode = () => {
	return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
};

const validThemeSetting = (theme) => {
	return ['dark', 'light', 'system'].indexOf(theme) >= 0;
};

// dark / light / system
const loadThemeSetting = () => {
	let str = localStorage.getItem('theme');
	if (!str || !validThemeSetting(str)) str = 'light';
	return str;
};

// dark / light
const loadTheme = () => {
	let setting = loadThemeSetting();
	if (setting === 'system') {
		setting = preferDarkMode() ? 'dark' : 'light';
	}
	return setting;
};

const saveThemeSetting = setting => {
	if (!validThemeSetting(setting)) setting = 'light';
	localStorage.setItem('theme', setting);
};

// when toggled, Auto will be changed to light or dark
const toggleTheme = () => {
	const theme = loadTheme();
	const newTheme = theme === 'dark' ? 'light' : 'dark';
	saveThemeSetting(newTheme);
	setTheme(newTheme);
};

const setTheme = (theme) => {
	if (!theme) theme = loadTheme();
	if (theme === 'dark') {
		$('html').css('background', 'rgb(20, 20, 20)');
		$('body').addClass('uk-light');
		$('.uk-card').addClass('uk-card-secondary');
		$('.uk-card').removeClass('uk-card-default');
		$('.ui-widget-content').addClass('dark');
	} else {
		$('html').css('background', '');
		$('body').removeClass('uk-light');
		$('.uk-card').removeClass('uk-card-secondary');
		$('.uk-card').addClass('uk-card-default');
		$('.ui-widget-content').removeClass('dark');
	}
};

const styleModal = () => {
	const color = loadTheme() === 'dark' ? '#222' : '';
	$('.uk-modal-header').css('background', color);
	$('.uk-modal-body').css('background', color);
	$('.uk-modal-footer').css('background', color);
};

// do it before document is ready to prevent the initial flash of white on
// 	most pages
setTheme();

$(() => {
	// hack for the reader page
	setTheme();

	// on system dark mode setting change
	if (window.matchMedia) {
		window.matchMedia('(prefers-color-scheme: dark)')
			.addEventListener('change', event => {
				if (loadThemeSetting() === 'system')
					setTheme(event.matches ? 'dark' : 'light');
			});
	}
});
