const gulp = require('gulp');
const babel = require('gulp-babel');
const minify = require('gulp-babel-minify');
const minifyCss = require('gulp-minify-css');
const less = require('gulp-less');

gulp.task('copy-uikit-js', () => {
	return gulp.src([
			'node_modules/uikit/dist/js/uikit.min.js',
			'node_modules/uikit/dist/js/uikit-icons.min.js'
		])
		.pipe(gulp.dest('public/js'));
});

gulp.task('copy-fontawesome', () => {
	return gulp.src([
			'node_modules/@fortawesome/fontawesome-free/js/fontawesome.min.js',
			'node_modules/@fortawesome/fontawesome-free/js/solid.min.js'
		])
		.pipe(gulp.dest('public/js'));
});

gulp.task('copy-js', gulp.series('copy-uikit-js', 'copy-fontawesome'));

gulp.task('babel', () => {
	return gulp.src(['public/js/*.js'])
		.pipe(babel({
			presets: [
				['@babel/preset-env', {
					debug: true,
					targets: '>0.25%, not dead, ios>=9'
				}]
			],
		}))
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
	gulp.series('copy-js', 'babel'),
	gulp.series('less', 'minify-css'),
	gulp.series('copy-uikit-icons', 'img'),
	'copy-files'
));

gulp.task('dev', gulp.parallel(
	'copy-js', 'less', 'copy-uikit-icons'
));
