const component = () => {
	return {
		subscriptions: [],
		plugins: [],
		pid: undefined,

		init() {
			fetch(`${base_url}api/admin/plugin`)
				.then((res) => res.json())
				.then((data) => {
					if (!data.success) throw new Error(data.error);
					this.plugins = data.plugins;

					const pid = localStorage.getItem("plugin");
					if (pid && this.plugins.map((p) => p.id).includes(pid))
						this.pid = pid;
					else if (this.plugins.length > 0)
						this.pid = this.plugins[0].id;

					if (this.pid) this.list(pid);
				})
				.catch((e) => {
					alert(
						"danger",
						`Failed to list the available plugins. Error: ${e}`
					);
				});
		},
		pluginChanged() {
			localStorage.setItem("plugin", this.pid);
			this.list(this.pid);
		},
		list(pid) {
			fetch(
				`${base_url}api/admin/plugin/subscriptions?${new URLSearchParams(
					{
						plugin: pid,
					}
				)}`,
				{
					method: "GET",
				}
			)
				.then((response) => response.json())
				.then((data) => {
					if (!data.success) throw new Error(data.error);
					this.subscriptions = data.subscriptions;
				})
				.catch((e) => {
					alert(
						"danger",
						`Failed to list subscriptions. Error: ${e}`
					);
				});
		},
	};
};
