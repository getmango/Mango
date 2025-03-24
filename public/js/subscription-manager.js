const component = () => {
  return {
    subscriptions: [],
    plugins: [],
    pid: undefined,
    subscription: undefined, // selected subscription
    loading: false,

    init() {
      fetch(`${base_url}api/admin/plugin`)
        .then((res) => res.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          this.plugins = data.plugins;

          let pid = localStorage.getItem('plugin');
          if (!pid || !this.plugins.find((p) => p.id === pid)) {
            pid = this.plugins[0].id;
          }

          this.pid = pid;
          this.list(pid);
        })
        .catch((e) => {
          alert('danger', `Failed to list the available plugins. Error: ${e}`);
        });
    },
    pluginChanged() {
      localStorage.setItem('plugin', this.pid);
      this.list(this.pid);
    },
    list(pid) {
      if (!pid) return;
      fetch(
        `${base_url}api/admin/plugin/subscriptions?${new URLSearchParams({
          plugin: pid,
        })}`,
        {
          method: 'GET',
        },
      )
        .then((response) => response.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          this.subscriptions = data.subscriptions;
        })
        .catch((e) => {
          alert('danger', `Failed to list subscriptions. Error: ${e}`);
        });
    },
    renderStrCell(str) {
      const maxLength = 40;
      if (str.length > maxLength)
        return `<td><span>${str.substring(
          0,
          maxLength,
        )}...</span><div uk-dropdown>${str}</div></td>`;
      return `<td>${str}</td>`;
    },
    renderDateCell(timestamp) {
      return `<td>${moment
        .duration(moment.unix(timestamp).diff(moment()))
        .humanize(true)}</td>`;
    },
    selected(event, modal) {
      const id = event.currentTarget.getAttribute('sid');
      this.subscription = this.subscriptions.find((s) => s.id === id);
      UIkit.modal(modal).show();
    },
    renderFilterRow(ft) {
      const key = ft.key;
      let type = ft.type;
      switch (type) {
        case 'number-min':
          type = 'number (minimum value)';
          break;
        case 'number-max':
          type = 'number (maximum value)';
          break;
        case 'date-min':
          type = 'minimum date';
          break;
        case 'date-max':
          type = 'maximum date';
          break;
      }
      let value = ft.value;

      if (ft.type.startsWith('number') && isNaN(value)) value = '';
      else if (ft.type.startsWith('date') && value)
        value = moment(Number(value)).format('MMM D, YYYY');

      return `<td>${key}</td><td>${type}</td><td>${value}</td>`;
    },
    actionHandler(event, type) {
      const id = $(event.currentTarget).closest('tr').attr('sid');
      if (type !== 'delete') return this.action(id, type);
      UIkit.modal
        .confirm(
          'Are you sure you want to delete the subscription? This cannot be undone.',
          {
            labels: {
              ok: 'Yes, delete it',
              cancel: 'Cancel',
            },
          },
        )
        .then(() => {
          this.action(id, type);
        });
    },
    action(id, type) {
      if (this.loading) return;
      this.loading = true;
      fetch(
        `${base_url}api/admin/plugin/subscriptions${
          type === 'update' ? '/update' : ''
        }?${new URLSearchParams({
          plugin: this.pid,
          subscription: id,
        })}`,
        {
          method: type === 'delete' ? 'DELETE' : 'POST',
        },
      )
        .then((response) => response.json())
        .then((data) => {
          if (!data.success) throw new Error(data.error);
          if (type === 'update')
            alert(
              'success',
              `Checking updates for subscription ${id}. Check the log for the progress or come back to this page later.`,
            );
        })
        .catch((e) => {
          alert('danger', `Failed to ${type} subscription. Error: ${e}`);
        })
        .finally(() => {
          this.loading = false;
          this.list(this.pid);
        });
    },
  };
};
