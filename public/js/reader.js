$(function() {
	function bind() {
		var controller = new ScrollMagic.Controller();

		// replace history on scroll
		$('img').each(function(idx){
			var scene = new ScrollMagic.Scene({
				triggerElement: $(this).get(),
				triggerHook: 'onEnter',
				reverse: true
			})
				.addTo(controller)
				.on('enter', function(event){
					current = $(event.target.triggerElement()).attr('id');
					replaceHistory(current);
				})
				.on('leave', function(event){
					var prev = $(event.target.triggerElement()).prev();
					current = $(prev).attr('id');
					replaceHistory(current);
				});
		});

		// poor man's infinite scroll
		var scene = new ScrollMagic.Scene({
			triggerElement: $('.next-url').get(),
			triggerHook: 'onEnter',
			offset: -500
		})
			.addTo(controller)
			.on('enter', function(){
				var nextURL = $('.next-url').attr('href');
				$('.next-url').remove();
				if (!nextURL) {
					console.log('No .next-url found. Reached end of page');
					var lastURL = $('img').last().attr('id');
					// load the reader URL for the last page to update reading progrss to 100%
					$.get(lastURL);
					return;
				}
				$('#hidden').load(nextURL + ' .uk-container', function(res, status, xhr){
					if (status === 'error') console.log(xhr.statusText);
					if (status === 'success') {
						console.log(nextURL + ' loaded');
						// new page loaded to #hidden, we now append it
						$('.uk-section > .uk-container').append($('#hidden .uk-container').children());
						$('#hidden').empty();
						bind();
					}
				});
			});
	}

	bind();
});
$('#page-select').change(function(){
	jumpTo(parseInt($('#page-select').val()));
});
function showControl(idx) {
	$('#page-select').val(idx + 1);
	UIkit.modal($('#modal-sections')).show();
}
function jumpTo(page) {
	var ary = window.location.pathname.split('/');
	ary[ary.length - 1] = page - 1;
	ary.shift(); // remove leading `/`
	ary.unshift(window.location.origin);
	window.location.replace(ary.join('/'));
}
function replaceHistory(url) {
	history.replaceState(null, "", url);
	console.log('reading ' + url);
}
function exit(url) {
	window.location.replace(url);
}
