const gulp = require('gulp');
const minify = require("gulp-babel-minify");
const minifyCss = require('gulp-minify-css');
const less = require('gulp-less');

gulp.task('minify-js', () => {
	return gulp.src('public/js/*.js')
		.pipe(minify({
			removeConsole: true
		}))
		.pipe(gulp.dest('dist/js'));
});

gulp.task('less', () => {
	return gulp.src('src/assets/*.less')
		.pipe(less())
		.pipe(gulp.dest('public/css'));
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

gulp.task('copy-files', () => {
	return gulp.src('public/*.*')
		.pipe(gulp.dest('dist'));
});

gulp.task('default', gulp.parallel('minify-js', gulp.series('less', 'minify-css'), 'img', 'copy-files'));
