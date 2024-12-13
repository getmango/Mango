$(() => {
  let target = base_url + 'admin/user/edit';
  if (username) target += username;
  $('form').attr('action', target);
  if (error) alert('danger', error);
});
