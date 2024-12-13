const component = () => {
  return {
    empty: true,
    titles: [],
    entries: [],
    loading: true,

    load() {
      this.loading = true;
      this.request('GET', `${base_url}api/admin/titles/missing`, (data) => {
        this.titles = data.titles;
        this.request('GET', `${base_url}api/admin/entries/missing`, (data) => {
          this.entries = data.entries;
          this.loading = false;
          this.empty = this.entries.length === 0 && this.titles.length === 0;
        });
      });
    },
    rm(event) {
      const rawID = event.currentTarget.closest('tr').id;
      const [type, id] = rawID.split('-');
      const url = `${base_url}api/admin/${
        type === 'title' ? 'titles' : 'entries'
      }/missing/${id}`;
      this.request('DELETE', url, () => {
        this.load();
      });
    },
    rmAll() {
      UIkit.modal
        .confirm(
          'Are you sure? All metadata associated with these items, including their tags and thumbnails, will be deleted from the database.',
          {
            labels: {
              ok: 'Yes, delete them',
              cancel: 'Cancel',
            },
          },
        )
        .then(() => {
          this.request('DELETE', `${base_url}api/admin/titles/missing`, () => {
            this.request(
              'DELETE',
              `${base_url}api/admin/entries/missing`,
              () => {
                this.load();
              },
            );
          });
        });
    },
    request(method, url, cb) {
      console.log(url);
      $.ajax({
        type: method,
        url,
        contentType: 'application/json',
      })
        .done((data) => {
          if (data.error) {
            alert('danger', `Failed to ${method} ${url}. Error: ${data.error}`);
            return;
          }
          if (cb) cb(data);
        })
        .fail((jqXHR, status) => {
          alert(
            'danger',
            `Failed to ${method} ${url}. Error: [${jqXHR.status}] ${jqXHR.statusText}`,
          );
        });
    },
  };
};
