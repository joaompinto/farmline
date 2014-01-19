library farmline;

import 'dart:html' as html;
import 'dart:math' as math;
import 'package:stagexl/stagexl.dart';

part 'src/gameboard.dart';
part 'src/products.dart';

Stage stage;

void main() {
  // setup the Stage and RenderLoop
  var canvas = html.querySelector('#stage');
  stage = new Stage('myStage', canvas);
  var renderLoop = new RenderLoop();
  renderLoop.addStage(stage);
  var juggler = renderLoop.juggler;

  loadResources();
}

void loadResources() {

  var resourceManager = new ResourceManager();

   for(int i=1; i<8; ++i) {
    resourceManager
      ..addBitmapData("piece_$i", "../common/images/products/$i.png");
   }

  resourceManager.load().then((res) {
    var gameBoard = new GameBoard(resourceManager, stage.juggler);
    stage.addChild(gameBoard);
  });
}