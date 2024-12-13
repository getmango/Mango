$(function () {
  let filter = [];
  let result = [];
  $('.uk-card-title').each(function () {
    filter.push($(this).text());
  });
  $('.uk-search-input').keyup(function () {
    let input = $('.uk-search-input').val();
    let regex = new RegExp(input, 'i');

    if (input === '') {
      $('.item').each(function () {
        $(this).removeAttr('hidden');
      });
    } else {
      filter.forEach(function (text, i) {
        result[i] = text.match(regex);
      });
      $('.item').each(function (i) {
        if (result[i]) {
          $(this).removeAttr('hidden');
        } else {
          $(this).attr('hidden', '');
        }
      });
    }
  });
});
