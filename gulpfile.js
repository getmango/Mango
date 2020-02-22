const gulp = require('gulp');
const minify = require("gulp-babel-minify");
const minifyCss = require('gulp-minify-css');

gulp.task('minify-js', () => {
	return gulp.src('public/js/*.js')
		.pipe(minify())
		.pipe(gulp.dest('dist/js'));
});

gulp.task('minify-css', () => {
	return gulp.src('public/css/*.css')
		.pipe(minifyCss())
		.pipe(gulp.dest('dist/css'));
});

gulp.task('img', () => {
	return gulp.src('public/img/*')
		.pipe(gulp.dest('dist/img'));
});

gulp.task('favicon', () => {
	return gulp.src('public/favicon.ico')
		.pipe(gulp.dest('dist'));
});

gulp.task('default', gulp.parallel('minify-js', 'minify-css', 'img', 'favicon'));
