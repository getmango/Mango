/**
 * Set an alpine.js property
 *
 * @function setProp
 * @param {string} key - Key of the data property
 * @param {*} prop - The data property
 * @param {string} selector - The jQuery selector to the root element
 */
const setProp = (key, prop, selector = '#root') => {
	$(selector).get(0).__x.$data[key] = prop;
};

/**
 * Get an alpine.js property
 *
 * @function getProp
 * @param {string} key - Key of the data property
 * @param {string} selector - The jQuery selector to the root element
 * @return {*} The data property
 */
const getProp = (key, selector = '#root') => {
	return $(selector).get(0).__x.$data[key];
};
