$("body").append(`
<a id="back-top">
    <svg style="display: block;margin: auto;height: 100%;" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" focusable="false" width="1em" height="1em" style="-ms-transform: rotate(360deg); -webkit-transform: rotate(360deg); transform: rotate(360deg);" preserveAspectRatio="xMidYMid meet" viewBox="0 0 8 8"><path d="M4 1L0 5l1.5 1.5L4 4l2.5 2.5L8 5L4 1z" fill="#626262"/></svg>
</a>
<style>
    #back-top{
        background:rgb(216, 216, 216);
        z-index: 1000;
        position: fixed;bottom: 5%;
        right: 7%;
        width:48px;
        height:38px;
        display: none;
    }

    #back-top.back-top-dark{
        background:rgba(10, 10, 12, 0.8);
    }
</style>
`)
$(function () {
    if ($("body").hasClass("uk-light")) {
        $("#back-top").addClass("back-top-dark")
    }
    if ($(window).scrollTop() > 0) {
        $("#back-top").fadeIn("fast");
    }

})
$(".uk-navbar-nav li:first-child a").click(() => {
    $("#back-top").toggleClass("back-top-dark")
})
$(window).scroll(function () {

    let top = $(this).scrollTop();

    if (top > 0) {
        $("#back-top").fadeIn("fast");

    } else {
        $("#back-top").fadeOut("fast");
    }
});
$("#back-top").click(function () {
    let t = 300
    if ($(window).scrollTop() / 4 > 300) {
        t = $(window).scrollTop() / 4
    }
    $("body , html").animate({ scrollTop: 0 }, t);
});
