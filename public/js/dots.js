/**
 * Truncate a .uk-card-title element
 *
 * @function truncate
 * @param {object} e - The title element to truncate
 */
const truncate = (e) => {
  $(e).dotdotdot({
    truncate: 'letter',
    watch: true,
    callback: (truncated) => {
      if (truncated) {
        $(e).attr('uk-tooltip', $(e).attr('data-title'));
      } else {
        $(e).removeAttr('uk-tooltip');
      }
    },
  });
};

$('.uk-card-title').each((i, e) => {
  // Truncate the title when it first enters the view
  $(e).one('inview', () => {
    truncate(e);
  });
});
