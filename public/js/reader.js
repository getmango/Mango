const readerComponent = () => {
  return {
    loading: true,
    mode: 'continuous', // Can be 'continuous', 'height' or 'width'
    msg: 'Loading the web reader. Please wait...',
    alertClass: 'uk-alert-primary',
    items: [],
    curItem: {},
    enableFlipAnimation: true,
    flipAnimation: null,
    longPages: false,
    lastSavedPage: page,
    selectedIndex: 0, // 0: not selected; 1: the first page
    margin: 30,
    preloadLookahead: 3,
    enableRightToLeft: false,
    fitType: 'vert',

    /**
     * Initialize the component by fetching the page dimensions
     */
    init(nextTick) {
      $.get(`${base_url}api/dimensions/${tid}/${eid}`)
        .then((data) => {
          if (!data.success && data.error) throw new Error(resp.error);
          const dimensions = data.dimensions;

          this.items = dimensions.map((d, i) => {
            return {
              id: i + 1,
              url: `${base_url}api/page/${tid}/${eid}/${i + 1}`,
              width: d.width === 0 ? '100%' : d.width,
              height: d.height === 0 ? '100%' : d.height,
            };
          });

          // Note: for image types not supported by image_size.cr, the width and height will be 0, and so `avgRatio` will be `Infinity`.
          // TODO: support more image types in image_size.cr
          const avgRatio =
            dimensions.reduce((acc, cur) => {
              return acc + cur.height / cur.width;
            }, 0) / dimensions.length;

          console.log(avgRatio);
          this.longPages = avgRatio > 2;
          this.loading = false;
          this.mode = localStorage.getItem('mode') || 'continuous';

          // Here we save a copy of this.mode, and use the copy as
          // 	the model-select value. This is because `updateMode`
          // 	might change this.mode and make it `height` or `width`,
          // 	which are not available in mode-select
          const mode = this.mode;
          this.updateMode(this.mode, page, nextTick);
          $('#mode-select').val(mode);

          const savedMargin = localStorage.getItem('margin');
          if (savedMargin) {
            this.margin = savedMargin;
          }

          // Preload Images
          this.preloadLookahead = +(
            localStorage.getItem('preloadLookahead') ?? 3
          );
          const limit = Math.min(
            page + this.preloadLookahead,
            this.items.length,
          );
          for (let idx = page + 1; idx <= limit; idx++) {
            this.preloadImage(this.items[idx - 1].url);
          }

          const savedFitType = localStorage.getItem('fitType');
          if (savedFitType) {
            this.fitType = savedFitType;
            $('#fit-select').val(savedFitType);
          }
          const savedFlipAnimation = localStorage.getItem(
            'enableFlipAnimation',
          );
          this.enableFlipAnimation =
            savedFlipAnimation === null || savedFlipAnimation === 'true';

          const savedRightToLeft = localStorage.getItem('enableRightToLeft');
          if (savedRightToLeft === null) {
            this.enableRightToLeft = false;
          } else {
            this.enableRightToLeft = savedRightToLeft === 'true';
          }
        })
        .catch((e) => {
          const errMsg = `Failed to get the page dimensions. ${e}`;
          console.error(e);
          this.alertClass = 'uk-alert-danger';
          this.msg = errMsg;
        });
    },
    /**
     * Preload an image, which is expected to be cached
     */
    preloadImage(url) {
      new Image().src = url;
    },
    /**
     * Handles the `change` event for the page selector
     */
    pageChanged() {
      const p = parseInt($('#page-select').val());
      this.toPage(p);
    },
    /**
     * Handles the `change` event for the mode selector
     *
     * @param {function} nextTick - Alpine $nextTick magic property
     */
    modeChanged(nextTick) {
      const mode = $('#mode-select').val();
      const curIdx = parseInt($('#page-select').val());

      this.updateMode(mode, curIdx, nextTick);
    },
    /**
     * Handles the window `resize` event
     */
    resized() {
      if (this.mode === 'continuous') return;

      const wideScreen = $(window).width() > $(window).height();
      this.mode = wideScreen ? 'height' : 'width';
    },
    /**
     * Handles the window `keydown` event
     *
     * @param {Event} event - The triggering event
     */
    keyHandler(event) {
      if (this.mode === 'continuous') return;

      if (event.key === 'ArrowLeft' || event.key === 'k')
        this.flipPage(false ^ this.enableRightToLeft);
      if (event.key === 'ArrowRight' || event.key === 'j')
        this.flipPage(true ^ this.enableRightToLeft);
    },
    /**
     * Flips to the next or the previous page
     *
     * @param {bool} isNext - Whether we are going to the next page
     */
    flipPage(isNext) {
      const idx = parseInt(this.curItem.id);
      const newIdx = idx + (isNext ? 1 : -1);

      if (newIdx <= 0) return;
      if (newIdx > this.items.length) {
        this.showControl(idx);
        return;
      }

      if (newIdx + this.preloadLookahead < this.items.length + 1) {
        this.preloadImage(this.items[newIdx + this.preloadLookahead - 1].url);
      }

      this.toPage(newIdx);

      if (this.enableFlipAnimation) {
        if (isNext ^ this.enableRightToLeft) this.flipAnimation = 'right';
        else this.flipAnimation = 'left';
      }

      setTimeout(() => {
        this.flipAnimation = null;
      }, 500);

      this.replaceHistory(newIdx);
    },
    /**
     * Jumps to a specific page
     *
     * @param {number} idx - One-based index of the page
     */
    toPage(idx) {
      if (this.mode === 'continuous') {
        $(`#${idx}`).get(0).scrollIntoView(true);
      } else {
        if (idx >= 1 && idx <= this.items.length) {
          this.curItem = this.items[idx - 1];
        }
      }
      this.replaceHistory(idx);
      UIkit.modal($('#modal-sections')).hide();
    },
    /**
     * Replace the address bar history and save the reading progress if necessary
     *
     * @param {number} idx - One-based index of the page
     */
    replaceHistory(idx) {
      const ary = window.location.pathname.split('/');
      ary[ary.length - 1] = idx;
      ary.shift(); // remove leading `/`
      ary.unshift(window.location.origin);
      const url = ary.join('/');
      this.saveProgress(idx);
      history.replaceState(null, '', url);
    },
    /**
     * Updates the backend reading progress if:
     * 		1) the current page is more than five pages away from the last
     * 			saved page, or
     * 		2) the average height/width ratio of the pages is over 2, or
     * 		3) the current page is the first page, or
     * 		4) the current page is the last page
     *
     * @param {number} idx - One-based index of the page
     * @param {function} cb - Callback
     */
    saveProgress(idx, cb) {
      idx = parseInt(idx);
      if (
        Math.abs(idx - this.lastSavedPage) >= 5 ||
        this.longPages ||
        idx === 1 ||
        idx === this.items.length
      ) {
        this.lastSavedPage = idx;
        console.log('saving progress', idx);

        const url = `${base_url}api/progress/${tid}/${idx}?${$.param({
          eid,
        })}`;
        $.ajax({
          method: 'PUT',
          url,
          dataType: 'json',
        })
          .done((data) => {
            if (data.error) alert('danger', data.error);
            if (cb) cb();
          })
          .fail((jqXHR, status) => {
            alert('danger', `Error: [${jqXHR.status}] ${jqXHR.statusText}`);
          });
      }
    },
    /**
     * Updates the reader mode
     *
     * @param {string} mode - Either `continuous` or `paged`
     * @param {number} targetPage - The one-based index of the target page
     * @param {function} nextTick - Alpine $nextTick magic property
     */
    updateMode(mode, targetPage, nextTick) {
      localStorage.setItem('mode', mode);

      // The mode to be put into the `mode` prop. It can't be `screen`
      let propMode = mode;

      if (mode === 'paged') {
        const wideScreen = $(window).width() > $(window).height();
        propMode = wideScreen ? 'height' : 'width';
      }

      this.mode = propMode;

      if (mode === 'continuous') {
        nextTick(() => {
          this.setupScroller();
        });
      }

      nextTick(() => {
        this.toPage(targetPage);
      });
    },
    /**
     * Handles clicked image
     *
     * @param {Event} event - The triggering event
     */
    clickImage(event) {
      const idx = event.currentTarget.id;
      this.showControl(idx);
    },
    /**
     * Shows the control modal
     *
     * @param {number} idx - selected page index
     */
    showControl(idx) {
      this.selectedIndex = idx;
      UIkit.modal($('#modal-sections')).show();
    },
    /**
     * Redirects to a URL
     *
     * @param {string} url - The target URL
     */
    redirect(url) {
      window.location.replace(url);
    },
    /**
     * Set up the scroll handler that calls `replaceHistory` when an image
     * 	enters the view port
     */
    setupScroller() {
      if (this.mode !== 'continuous') return;
      $('img').each((idx, el) => {
        $(el).on('inview', (event, inView) => {
          if (inView) {
            const current = $(event.currentTarget).attr('id');

            this.curItem = this.items[current - 1];
            this.replaceHistory(current);
          }
        });
      });
    },
    /**
     * Marks progress as 100% and jumps to the next entry
     *
     * @param {string} nextUrl - URL of the next entry
     */
    nextEntry(nextUrl) {
      this.saveProgress(this.items.length, () => {
        this.redirect(nextUrl);
      });
    },
    /**
     * Exits the reader, and sets the reading progress tp 100%
     *
     * @param {string} exitUrl - The Exit URL
     */
    exitReader(exitUrl) {
      this.saveProgress(this.items.length, () => {
        this.redirect(exitUrl);
      });
    },

    /**
     * Handles the `change` event for the entry selector
     */
    entryChanged() {
      const id = $('#entry-select').val();
      this.redirect(`${base_url}reader/${tid}/${id}`);
    },

    marginChanged() {
      localStorage.setItem('margin', this.margin);
      this.toPage(this.selectedIndex);
    },

    fitChanged() {
      this.fitType = $('#fit-select').val();
      localStorage.setItem('fitType', this.fitType);
    },

    preloadLookaheadChanged() {
      localStorage.setItem('preloadLookahead', this.preloadLookahead);
    },

    enableFlipAnimationChanged() {
      localStorage.setItem('enableFlipAnimation', this.enableFlipAnimation);
    },

    enableRightToLeftChanged() {
      localStorage.setItem('enableRightToLeft', this.enableRightToLeft);
    },
  };
};
