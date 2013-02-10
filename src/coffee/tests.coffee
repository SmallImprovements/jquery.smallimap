###!
Test suite for jQuery Smallimap
###

# Prepare test suite
mapOptions =
  dotRadius: 3
  width: 920
  height: 460
  colors:
    lights: ["#fdf6e3", "#fafafa", "#dddddd", "#cccccc", "#bbbbbb"]
    darks: ["#777777", "#888888", "#999999", "#aaaaaa"]

# Init smallipops
$('.smallipop').smallipop
  theme: 'black'
  cssAnimations:
    enabled: true
    show: 'animated flipInX'
    hide: 'animated flipOutX'

# Init map
window.smallimap = $('#smallimap').smallimap(mapOptions).data('api')

# Init metrics client
smallimap.run()

# Run test suite
module 'core'

test 'Smallimap exists', ->
  expect 1

  smallimap = $ '#smallimap canvas'

  equal smallimap.length, 1, 'One canvas should have been created'
