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

// https://stackoverflow.com/a/28344281
const hasClass = (ele,cls) => {
  return !!ele.className.match(new RegExp('(\\s|^)'+cls+'(\\s|$)'));
};
const addClass = (ele,cls) => {
  if (!hasClass(ele,cls)) ele.className += " "+cls;
};
const removeClass = (ele,cls) => {
  if (hasClass(ele,cls)) {
    var reg = new RegExp('(\\s|^)'+cls+'(\\s|$)');
    ele.className=ele.className.replace(reg,' ');
  }
};

const addClassToClass = (targetCls, newCls) => {
	const elements = document.getElementsByClassName(targetCls);
	for (let i = 0; i < elements.length; i++) {
		addClass(elements[i], newCls);
	}
};

const removeClassFromClass = (targetCls, newCls) => {
	const elements = document.getElementsByClassName(targetCls);
	for (let i = 0; i < elements.length; i++) {
		removeClass(elements[i], newCls);
	}
};

const setTheme = themeStr => {
	if (themeStr === 'dark') {
		document.getElementsByTagName('html')[0].style.background = 'rgb(20, 20, 20)';
		addClass(document.getElementsByTagName('body')[0], 'uk-light');
		addClassToClass('uk-card', 'uk-card-secondary');
		removeClassFromClass('uk-card', 'uk-card-default');
	}
	else {
		document.getElementsByTagName('html')[0].style.background = '';
		removeClass(document.getElementsByTagName('body')[0], 'uk-light');
		removeClassFromClass('uk-card', 'uk-card-secondary');
		addClassToClass('uk-card', 'uk-card-default');
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

document.addEventListener('DOMContentLoaded', () => {
	// because this script is attached at the top of HTML, the style on uk-card
	// 	won't be applied because the elements are not available yet. We have to
	// 	apply the theme again for it to take effect
	setTheme(getTheme());
}, false);
