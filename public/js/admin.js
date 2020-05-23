var scanning = false;
function scan() {
	scanning = true;
	$('#scan-status > div').removeAttr('hidden');
	$('#scan-status > span').attr('hidden', '');
	var color = $('#scan').css('color');
	$('#scan').css('color', 'gray');
	$.post(base_url + 'api/admin/scan', function (data) {
		var ms = data.milliseconds;
		var titles = data.titles;
		$('#scan-status > span').text('Scanned ' + titles + ' titles in ' + ms + 'ms');
		$('#scan-status > span').removeAttr('hidden');
		$('#scan').css('color', color);
		$('#scan-status > div').attr('hidden', '');
		scanning = false;
	});
}
$(function() {
	$('li').click(function() {
		url = $(this).attr('data-url');
		if (url) {
			$(location).attr('href', url);
		}
	});
});
