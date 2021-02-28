const gulp = require('gulp');
const babel = require('gulp-babel');
const minify = require('gulp-babel-minify');
const minifyCss = require('gulp-minify-css');
const less = require('gulp-less');

gulp.task('copy-img', () => {
	return gulp.src('node_modules/uikit/src/images/backgrounds/*.svg')
		.pipe(gulp.dest('public/img'));
});

gulp.task('copy-font', () => {
	return gulp.src('node_modules/@fortawesome/fontawesome-free/webfonts/fa-solid-900.woff**')
		.pipe(gulp.dest('public/webfonts'));
});

// Copy files from node_modules
gulp.task('node-modules-copy', gulp.parallel('copy-img', 'copy-font'));

// Compile less
gulp.task('less', () => {
	return gulp.src([
			'public/css/mango.less',
			'public/css/tags.less'
		])
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
	return gulp.src([
			'public/*.*',
			'public/img/*',
			'public/webfonts/*',
			'public/js/*.min.js'
		], {
			base: 'public'
		})
		.pipe(gulp.dest('dist'));
});

// Set up the public folder for development
gulp.task('dev', gulp.parallel('node-modules-copy', 'less'));

// Set up the dist folder for deployment
gulp.task('deploy', gulp.parallel('babel', 'minify-css', 'copy-files'));

// Default task
gulp.task('default', gulp.series('dev', 'deploy'));
