$(() => {
  $('#sort-select').change(() => {
    const sort = $('#sort-select').find(':selected').attr('id');
    const ary = sort.split('-');
    const by = ary[0];
    const dir = ary[1];

    const url = `${location.protocol}//${location.host}${location.pathname}`;
    const newURL = `${url}?${$.param({
      sort: by,
      ascend: dir === 'up' ? 1 : 0,
    })}`;
    window.location.href = newURL;
  });
});
