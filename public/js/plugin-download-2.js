const component = () => {
	return {
		plugins: [],
		info: undefined,
		pid: undefined,
		init() {
			fetch(`${base_url}api/admin/plugin`)
				.then(res => res.json())
				.then(data => {
					if (!data.success) {
						alert('danger', `Failed to list the available plugins. Error: ${data.error}`);
						return;
					}
					this.plugins = data.plugins;

					const pid = localStorage.getItem('plugin');
					if (pid && this.plugins.map(p => p.id).includes(pid))
						return this.loadPlugin(pid);

					if (this.plugins.length > 0)
						this.loadPlugin(this.plugins[0].id);
				});
		},
		loadPlugin(pid) {
			fetch(`${base_url}api/admin/plugin/info?${new URLSearchParams({
				plugin: pid
			})}`)
				.then(res => res.json())
				.then(data => {
					if (!data.success) {
						alert('danger', `Failed to get plugin metadata. Error: ${data.error}`);
						return;
					}
					this.info = data.info;
					this.pid = pid;
				});
		},
		pluginChanged() {
			this.loadPlugin(this.pid);
		}
	};
};
