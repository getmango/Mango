const component = () => {
  return {
    jobs: [],
    paused: undefined,
    loading: false,
    toggling: false,
    ws: undefined,

    wsConnect(secure = true) {
      const url = `${secure ? 'wss' : 'ws'}://${
        location.host
      }${base_url}api/admin/mangadex/queue`;
      console.log(`Connecting to ${url}`);
      this.ws = new WebSocket(url);
      this.ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.jobs = data.jobs;
        this.paused = data.paused;
      };
      this.ws.onclose = () => {
        if (this.ws.failed) return this.wsConnect(false);
        alert('danger', 'Socket connection closed');
      };
      this.ws.onerror = () => {
        if (secure) return (this.ws.failed = true);
        alert('danger', 'Socket connection failed');
      };
    },
    init() {
      this.wsConnect();
      this.load();
    },
    load() {
      this.loading = true;
      $.ajax({
        type: 'GET',
        url: base_url + 'api/admin/mangadex/queue',
        dataType: 'json',
      })
        .done((data) => {
          if (!data.success && data.error) {
            alert(
              'danger',
              `Failed to fetch download queue. Error: ${data.error}`,
            );
            return;
          }
          this.jobs = data.jobs;
          this.paused = data.paused;
        })
        .fail((jqXHR, status) => {
          alert(
            'danger',
            `Failed to fetch download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`,
          );
        })
        .always(() => {
          this.loading = false;
        });
    },
    jobAction(action, event) {
      let url = `${base_url}api/admin/mangadex/queue/${action}`;
      if (event) {
        const id = event.currentTarget
          .closest('tr')
          .id.split('-')
          .slice(1)
          .join('-');
        url = `${url}?${$.param({
          id,
        })}`;
      }
      console.log(url);
      $.ajax({
        type: 'POST',
        url,
        dataType: 'json',
      })
        .done((data) => {
          if (!data.success && data.error) {
            alert(
              'danger',
              `Failed to ${action} job from download queue. Error: ${data.error}`,
            );
            return;
          }
          this.load();
        })
        .fail((jqXHR, status) => {
          alert(
            'danger',
            `Failed to ${action} job from download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`,
          );
        });
    },
    toggle() {
      this.toggling = true;
      const action = this.paused ? 'resume' : 'pause';
      const url = `${base_url}api/admin/mangadex/queue/${action}`;
      $.ajax({
        type: 'POST',
        url,
        dataType: 'json',
      })
        .fail((jqXHR, status) => {
          alert(
            'danger',
            `Failed to ${action} download queue. Error: [${jqXHR.status}] ${jqXHR.statusText}`,
          );
        })
        .always(() => {
          this.load();
          this.toggling = false;
        });
    },
    statusClass(status) {
      let cls = 'label ';
      switch (status) {
        case 'Pending':
          cls += 'label-pending';
          break;
        case 'Completed':
          cls += 'label-success';
          break;
        case 'Error':
          cls += 'label-danger';
          break;
        case 'MissingPages':
          cls += 'label-warning';
          break;
      }
      return cls;
    },
  };
};
