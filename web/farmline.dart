library farmline;

import 'dart:html' as html;
import 'dart:math' as math;
import 'package:stagexl/stagexl.dart';

part 'src/gameboard.dart';
part 'src/products.dart';

Stage stage;

Bitmap loadingBitmap;
Tween loadingBitmapTween;
TextField loadingTextField;

void main() {
  // setup the Stage and RenderLoop
  var canvas = html.querySelector('#stage');
  stage = new Stage('myStage', canvas);
  var renderLoop = new RenderLoop();
  renderLoop.addStage(stage);
  
  //BitmapData.defaultLoadOptions.webp = true;

  BitmapData.load("../common/images/Loading.png").then((bitmapData) {

    loadingBitmap = new Bitmap(bitmapData);
    loadingBitmap
      ..pivotX = 20
      ..pivotY = 20
      ..x = 400
      ..y = 270;
    stage.addChild(loadingBitmap);

    loadingTextField = new TextField();
    loadingTextField.defaultTextFormat = new TextFormat("Arial", 20, 0xA0A0A0, bold:true);;
    loadingTextField
      ..width = 240
      ..height = 40
      ..text = "... loading ..."
      ..x = 400 - loadingTextField.textWidth / 2
      ..y = 320
      ..mouseEnabled = false;
    stage.addChild(loadingTextField);

    loadingBitmapTween = new Tween(loadingBitmap, 100, TransitionFunction.linear);
    loadingBitmapTween.animate.rotation.to(100.0 * 2.0 * math.PI);
    stage.juggler.add(loadingBitmapTween);

    loadResources();
  });
  
}

void loadResources() {

  var resourceManager = new ResourceManager();

   for(int i=1; i<8; ++i) {
    resourceManager
      ..addBitmapData("product_$i", "../common/images/products/$i.png");
   }

  resourceManager.load().then((res) {
    var gameBoard = new GameBoard(resourceManager, stage.juggler);
    stage.addChild(gameBoard);
  });
}