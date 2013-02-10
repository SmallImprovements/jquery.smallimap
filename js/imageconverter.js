
(function($) {
  var imageToJson, worldImage;
  imageToJson = function(img) {
    var alpha, blue, canvas, canvasObj, ctx, green, imageData, isLand, jsonData, pos, red, x, y, _i, _j, _ref, _ref1;
    canvasObj = $('<canvas>');
    canvas = canvasObj[0];
    $('body').append(canvasObj);
    canvas.width = img.width;
    canvas.height = img.height;
    console.log("Image width: " + img.width);
    console.log("Image height: " + img.height);
    ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0);
    jsonData = [];
    imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    console.log(imageData);
    for (y = _i = 0, _ref = imageData.width - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; y = 0 <= _ref ? ++_i : --_i) {
      jsonData[y] = [];
      for (x = _j = 0, _ref1 = imageData.height - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; x = 0 <= _ref1 ? ++_j : --_j) {
        pos = (x * imageData.width * 4) + y * 4;
        red = imageData.data[pos];
        green = imageData.data[pos + 1];
        blue = imageData.data[pos + 2];
        alpha = imageData.data[pos + 3];
        isLand = red + green + blue === 0;
        if (isLand) {
          imageData.data[pos] = 0;
          imageData.data[pos + 1] = 255;
          imageData.data[pos + 2] = 0;
        } else {
          imageData.data[pos] = 0;
          imageData.data[pos + 1] = 0;
          imageData.data[pos + 2] = 255;
        }
        jsonData[y][x] = isLand ? 1 : 0;
      }
    }
    ctx.putImageData(imageData, 0, 0);
    return jsonData;
  };
  console.log('Loading image');
  worldImage = new Image();
  $(worldImage).load(function() {
    var resultDiv, worldJson;
    console.log('Image loaded');
    console.log('Converting image');
    worldJson = imageToJson(worldImage);
    console.log('Result:');
    console.log(worldJson);
    resultDiv = $('<div>');
    resultDiv.text(JSON.stringify(worldJson));
    return $('body').append(resultDiv);
  });
  return worldImage.src = 'img/world.png';
})(jQuery);
