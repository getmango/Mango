$(() => {
	const setting = loadThemeSetting();
	$('#theme-select').val(capitalize(setting));
	$('#theme-select').change((e) => {
		const newSetting = $(e.currentTarget).val().toLowerCase();
		saveThemeSetting(newSetting);
		setTheme();
	});

	setInterval(getProgress, 5000);
});

/**
 * Capitalize String
 *
 * @function capitalize
 * @param {string} str - The string to be capitalized
 * @return {string} The capitalized string
 */
const capitalize = (str) => {
	return str.charAt(0).toUpperCase() + str.slice(1);
};

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
 * Get an alpine.js property
 *
 * @function getProp
 * @param {string} key - Key of the data property
 * @return {*} The data property
 */
const getProp = (key) => {
	return $('#root').get(0).__x.$data[key];
};

/**
 * Get the thumbnail generation progress from the API
 *
 * @function getProgress
 */
const getProgress = () => {
	$.get(`${base_url}api/admin/thumbnail_progress`)
		.then(data => {
			setProp('progress', data.progress);
			const generating = data.progress > 0
			setProp('generating', generating);
		});
};

/**
 * Trigger the thumbnail generation
 *
 * @function generateThumbnails
 */
const generateThumbnails = () => {
	setProp('generating', true);
	setProp('progress', 0.0);
	$.post(`${base_url}api/admin/generate_thumbnails`);
};

/**
 * Trigger the scan
 *
 * @function scan
 */
const scan = () => {
	setProp('scanning', true);
	setProp('scanMs', -1);
	setProp('scanTitles', 0);
	$.post(`${base_url}api/admin/scan`)
		.then(data => {
			setProp('scanMs', data.milliseconds);
			setProp('scanTitles', data.titles);
		})
		.always(() => {
			setProp('scanning', false);
		});
}
