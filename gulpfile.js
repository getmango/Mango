const gulp = require('gulp');
const uglify = require('gulp-uglify');
const minifyCss = require('gulp-minify-css');

gulp.task('minify-js', () => {
	return gulp.src('public/js/*.js')
		.pipe(uglify())
		.pipe(gulp.dest('dist/js'));
});

gulp.task('minify-css', () => {
	return gulp.src('public/css/*.css')
		.pipe(minifyCss())
		.pipe(gulp.dest('dist/css'));
});

gulp.task('default', gulp.parallel('minify-js', 'minify-css'));
