module.exports = (grunt) ->

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-qunit'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-sass'

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON 'smallimap.jquery.json'
    meta:
      banner: '/*!\n' +
        'jQuery <%= pkg.name %> plugin\n' +
        '@name jquery.<%= pkg.name %>.js\n' +
        '@author Sebastian Helzle (sebastian@helzle.net or @sebobo)\n' +
        '@author Tim Taubner (tim@small-improvements.com)\n' +
        '@version <%= pkg.version %>\n' +
        '@date <%= grunt.template.today("yyyy-mm-dd") %>\n' +
        '@category jQuery plugin\n' +
        '@copyright (c) 2012-2013 Small Improvements (http://www.small-improvements.com)\n' +
        '@license Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) license.\n' +
        '*/\n'
    qunit:
      files: ['tests/**/*.html']
    growl:
      coffee:
        title: 'grunt'
        message: 'Compiled coffeescript'
      sass:
        title: 'grunt'
        message: 'Compiled sass'
    coffee:
      compile:
        options:
          bare: true
        files:
          'js/jquery.smallimap.js': ['src/coffee/jquery.smallimap.coffee']
          'js/demo.js': ['src/coffee/demo.coffee']
          'js/imageconverter.js': ['src/coffee/imageconverter.coffee']
          'tests/tests.js': ['src/coffee/tests.coffee']
    watch:
      coffee:
        files: 'src/coffee/**/*.coffee',
        tasks: ['coffee:compile']#, 'growl:coffee']
      sass:
        files: 'src/scss/**/*.scss'
        tasks: ['sass:compile']#, 'growl:sass']
    sass:
      dist:
        options:
          style: 'compressed'
          compass: true
        files:
          'css/jquery.smallimap.min.css': 'src/scss/jquery.<%= pkg.name %>.scss'
      compile:
        options:
          style: 'expanded'
          compass: true
        files:
          'css/screen.css': 'src/scss/screen.scss'
          'css/jquery.smallimap.css': 'src/scss/jquery.<%= pkg.name %>.scss'
    uglify:
      dist:
        options:
          banner: '<%= meta.banner %>'
        files:
          'js/jquery.smallimap.min.js': ['js/jquery.<%= pkg.name %>.js']

  # Default task which watches, sass and coffee.
  grunt.registerTask 'default', ['watch']
  # Release task to run tests then minify js and css
  grunt.registerTask 'release', ['qunit', 'uglify', 'sass:dist']
