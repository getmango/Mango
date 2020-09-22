const gulp = require('gulp');
const babel = require('gulp-babel');
const minify = require('gulp-babel-minify');
const minifyCss = require('gulp-minify-css');
const less = require('gulp-less');

// Copy libraries from node_moduels to public/js
gulp.task('copy-js', () => {
	return gulp.src([
			'node_modules/@fortawesome/fontawesome-free/js/fontawesome.min.js',
			'node_modules/@fortawesome/fontawesome-free/js/solid.min.js',
			'node_modules/uikit/dist/js/uikit.min.js',
			'node_modules/uikit/dist/js/uikit-icons.min.js'
		])
		.pipe(gulp.dest('public/js'));
});

// Copy UIKit SVG icons to public/img
gulp.task('copy-uikit-icons', () => {
	return gulp.src('node_modules/uikit/src/images/backgrounds/*.svg')
		.pipe(gulp.dest('public/img'));
});

// Compile less
gulp.task('less', () => {
	return gulp.src('public/css/*.less')
		.pipe(less())
		.pipe(gulp.dest('public/css'));
});

// Transpile and minify JS files and output to dist
gulp.task('babel', () => {
	return gulp.src(['public/js/*.js', '!public/js/*.min.js'])
		.pipe(babel({
			presets: [
				['@babel/preset-env', {
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

// Minify CSS and output to dist
gulp.task('minify-css', () => {
	return gulp.src('public/css/*.css')
		.pipe(minifyCss())
		.pipe(gulp.dest('dist/css'));
});

// Copy static files (includeing images) to dist
gulp.task('copy-files', () => {
	return gulp.src(['public/img/*', 'public/*.*', 'public/js/*.min.js'], {
			base: 'public'
		})
		.pipe(gulp.dest('dist'));
});

// Set up the public folder for development
gulp.task('dev', gulp.parallel('copy-js', 'copy-uikit-icons', 'less'));

// Set up the dist folder for deployment
gulp.task('deploy', gulp.parallel('babel', 'minify-css', 'copy-files'));

// Default task
gulp.task('default', gulp.series('dev', 'deploy'));
