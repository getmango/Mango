let scanning = false;

const scan = () => {
	scanning = true;
	$('#scan-status > div').removeAttr('hidden');
	$('#scan-status > span').attr('hidden', '');
	const color = $('#scan').css('color');
	$('#scan').css('color', 'gray');
	$.post(base_url + 'api/admin/scan', (data) => {
		const ms = data.milliseconds;
		const titles = data.titles;
		$('#scan-status > span').text('Scanned ' + titles + ' titles in ' + ms + 'ms');
		$('#scan-status > span').removeAttr('hidden');
		$('#scan').css('color', color);
		$('#scan-status > div').attr('hidden', '');
		scanning = false;
	});
}

String.prototype.capitalize = function() {
	return this.charAt(0).toUpperCase() + this.slice(1);
}

$(() => {
	$('li').click((e) => {
		const url = $(e.currentTarget).attr('data-url');
		if (url) {
			$(location).attr('href', url);
		}
	});

	const setting = loadThemeSetting();
	$('#theme-select').val(setting.capitalize());

	$('#theme-select').change((e) => {
		const newSetting = $(e.currentTarget).val().toLowerCase();
		saveThemeSetting(newSetting);
		setTheme();
	});
});
