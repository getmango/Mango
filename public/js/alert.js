const alert = (level, text) => {
  $('#alert').empty();
  const html = `<div class="uk-alert-${level}" uk-alert><a class="uk-alert-close" uk-close></a><p>${text}</p></div>`;
  $('#alert').append(html);
  $('html, body').animate({ scrollTop: 0 });
};
