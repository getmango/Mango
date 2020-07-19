const gulp = require('gulp');
const minify = require("gulp-babel-minify");
const minifyCss = require('gulp-minify-css');
const less = require('gulp-less');

gulp.task('copy-uikit-js', () => {
	return gulp.src('node_modules/uikit/dist/js/*.min.js')
		.pipe(gulp.dest('public/js'));
});

gulp.task('minify-js', () => {
	return gulp.src('public/js/*.js')
		.pipe(minify({
			removeConsole: true,
			builtIns: false
		}))
		.pipe(gulp.dest('dist/js'));
});

gulp.task('less', () => {
	return gulp.src('public/css/*.less')
		.pipe(less())
		.pipe(gulp.dest('public/css'));
});

gulp.task('minify-css', () => {
	return gulp.src('public/css/*.css')
		.pipe(minifyCss())
		.pipe(gulp.dest('dist/css'));
});

gulp.task('copy-uikit-icons', () => {
	return gulp.src('node_modules/uikit/src/images/backgrounds/*.svg')
		.pipe(gulp.dest('public/img'));
});

gulp.task('img', () => {
	return gulp.src('public/img/*')
		.pipe(gulp.dest('dist/img'));
});

gulp.task('copy-files', () => {
	return gulp.src('public/*.*')
		.pipe(gulp.dest('dist'));
});

gulp.task('default', gulp.parallel(
	gulp.series('copy-uikit-js', 'minify-js'),
	gulp.series('less', 'minify-css'),
	gulp.series('copy-uikit-icons', 'img'),
	'copy-files'
));
