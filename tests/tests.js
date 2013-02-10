/*!
Test suite for jQuery Smallimap
*/

var mapOptions;

mapOptions = {
  dotRadius: 3,
  width: 920,
  height: 460,
  colors: {
    lights: ["#fdf6e3", "#fafafa", "#dddddd", "#cccccc", "#bbbbbb"],
    darks: ["#777777", "#888888", "#999999", "#aaaaaa"]
  }
};

$('.smallipop').smallipop({
  theme: 'black',
  cssAnimations: {
    enabled: true,
    show: 'animated flipInX',
    hide: 'animated flipOutX'
  }
});

window.smallimap = $('#smallimap').smallimap(mapOptions).data('api');

smallimap.run();

module('core');

test('Smallimap exists', function() {
  var smallimap;
  expect(1);
  smallimap = $('#smallimap canvas');
  return equal(smallimap.length, 1, 'One canvas should have been created');
});
