const component = () => {
	return {
		username: '',
		password: '',
		expires: undefined,
		loading: true,
		loggingIn: false,

		init() {
			this.loading = true;
			$.ajax({
					type: 'GET',
					url: `${base_url}api/admin/mangadex/expires`,
					contentType: "application/json",
				})
				.done(data => {
					console.log(data);
					if (data.error) {
						alert('danger', `Failed to retrieve MangaDex token status. Error: ${data.error}`);
						return;
					}
					this.expires = data.expires;
					this.loading = false;
				})
				.fail((jqXHR, status) => {
					alert('danger', `Failed to retrieve MangaDex token status. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
				});
		},
		login() {
			if (!(this.username && this.password)) return;
			this.loggingIn = true;
			$.ajax({
					type: 'POST',
					url: `${base_url}api/admin/mangadex/login`,
					contentType: "application/json",
					dataType: 'json',
					data: JSON.stringify({
						username: this.username,
						password: this.password
					})
				})
				.done(data => {
					console.log(data);
					if (data.error) {
						alert('danger', `Failed to log in. Error: ${data.error}`);
						return;
					}
					this.expires = data.expires;
				})
				.fail((jqXHR, status) => {
					alert('danger', `Failed to log in. Error: [${jqXHR.status}] ${jqXHR.statusText}`);
				})
				.always(() => {
					this.loggingIn = false;
				});
		},
		get expired() {
			return this.expires && moment().diff(moment.unix(this.expires)) > 0;
		}
	};
};
