const remove = (username) => {
  $.ajax({
    url: `${base_url}api/admin/user/delete/${username}`,
    type: 'DELETE',
    dataType: 'json',
  })
    .done((data) => {
      if (data.success) location.reload();
      else alert('danger', data.error);
    })
    .fail((jqXHR, status) => {
      alert(
        'danger',
        `Failed to delete the user. Error: [${jqXHR.status}] ${jqXHR.statusText}`,
      );
    });
};
