
const path = require('path');

const _ = require('lodash');
const Q = require('q');

const cp = require('process-promises');
const which = require('which-promise');

const gulp = require('gulp');
const gutil = require('gulp-util');
const coffee = require('gulp-coffee');
const jison = require('gulp-jison');
const raster = require('gulp-raster');
const rename = require('gulp-rename');

const minimist = require('minimist');


const knownOptions = {
    string: [ 'post-url' ],
    default: {
        'post-url': [
            'http://localhost:8888/'
        ]
    }
};

const options = minimist(process.argv.slice(2), knownOptions);


function jpm () {
    var args = [].slice.call(arguments);
    return which('firefox').then(function (ff) {
        const cwd = process.cwd();
        const env = process.env;
        return cp.spawn('jpm', ['--binary', ff].concat(args), {
            cwd: path.join(cwd, 'build'),
            env: _.extend({}, env, {
                PATH: env.PATH + ':' + path.join(cwd, 'node_modules', '.bin')
            })
        }).on('stdout', function(line) {
            console.log(line); 
        }).on('stderr', function(line) {
            console.error(line); 
        });
    });
}

gulp.task('default', ['jpm/run']);

gulp.task('watchpost', function () {
    gulp.watch([
        'src/**/*.ts',
        'src/**/*.html',
        'package.json'
    ], ['post']);
});

gulp.task('post', ['jpm/post']);

gulp.task('jpm/run', ['build'], function () {
    return jpm('run');
});

gulp.task('jpm/post', ['build'], function () {
    // Can't run `jpm post`s in parallel because they race for the .xpi file
    return _(options['post-url'])
        .concat()
        .map(url => () => jpm('post', '--post-url', url))
        .reduce((promise, task) => promise.then(task), Q());
});

gulp.task('build', [
    'build/package.json',
    'build/coffee',
    'build/jison',
    'build/locale',
    'build/svg',
    'build/static',
]);

gulp.task('build/package.json', function () {
    return gulp.src('package.json')
        .pipe(gulp.dest('build/'));
});

gulp.task('build/coffee', function() {
    return gulp.src('./src/**/*.coffee')
        .pipe(coffee({ bare: true }).on('error', gutil.log))
        .pipe(gulp.dest('./build/'));
});

gulp.task('build/jison', function() {
    return gulp.src('./src/**/*.jison')
        .pipe(jison({ moduleType: 'commonjs' }))
        .pipe(gulp.dest('./build/'));
});

gulp.task('build/locale', function() {
    return gulp.src('./src/chrome/locale/**/*.properties')
        .pipe(gulp.dest('./build/locale/'));
});

gulp.task('build/svg', [
    'build/svg/64',
    'build/svg/32',
    'build/svg/16',
]);

function gulpTaskRasterScale(scale, suffix) {
    return () => gulp.src('./src/**/*.svg')
        .pipe(raster({ scale: scale }))
        .pipe(rename({ extname: '.png', suffix: '-' + suffix }))
        .pipe(gulp.dest('./build/'));
}

gulp.task('build/svg/64', gulpTaskRasterScale(1, 64));
gulp.task('build/svg/32', gulpTaskRasterScale(1, 32));
gulp.task('build/svg/16', gulpTaskRasterScale(1, 16));

gulp.task('build/static', [
    'build/static/xul',
    'build/static/css',
    'build/static/ruleset',
]);

function gulpTaskCopyToBuildByFileExt(fileExt) {
    return () => gulp.src('src/**/*.' + fileExt)
        .pipe(gulp.dest('build/'));
}

gulp.task('build/static/xul', gulpTaskCopyToBuildByFileExt('xul'));
gulp.task('build/static/css', gulpTaskCopyToBuildByFileExt('css'));
gulp.task('build/static/ruleset', gulpTaskCopyToBuildByFileExt('ruleset'));



