/* */
part of farmline;

const GRID_ROWS = 10; // grid rows
const GRID_COLS = 10; // grid columns
const GRID_WIDTH = 60;
const GRID_HEIGHT = 60;

// game stats
const WAITING = 0; // Waiting for player move
const PUSHING = 1; // Player is pushing a piece
const SWITCHING = 2;  // Pieces are being switched
const IMPLODING = 3;  // Piece lines beng imploded

class GameBoard extends DisplayObjectContainer {


  final List<int> colors = [Color.Red, Color.Green, Color.Blue, Color.Brown];
  ResourceManager _resourceManager;
  Juggler _juggler;
  int gameState = WAITING;
  Point moveStart;
  Point moveStart_center;
  Point moveEnd;
  List pieces = new List(GRID_ROWS*GRID_COLS);
  int movingCount = 0;
  List _hLines = new List(); // List of horizontal lines to be imploded
  List _vLines = new List();  // List of vertical lines to be imploded
  int dropping_pieces = 0;
  var _rng  = new math.Random();

  GameBoard(ResourceManager resourceManager, Juggler juggler) {
    _resourceManager = resourceManager;
    _juggler = juggler;
    var background = new BitmapData(GRID_WIDTH*GRID_COLS, GRID_HEIGHT*GRID_ROWS,
        false, Color.BlanchedAlmond);
    var backgroundBitmap = new Bitmap(background);
    addChild(backgroundBitmap);

    // Fill game board with random products
    // Loop until we generated a board with no initial imploding products
    while(true) {
      for(int x=0; x < GRID_ROWS; ++x) {
        for(int y=0; y < GRID_COLS; ++y) {
          int face_id = 1 + _rng.nextInt(7);
          Product product = new Product(resourceManager.getBitmapData('piece_$face_id'),face_id);
          product.width = GRID_WIDTH-2;
          product.height = GRID_HEIGHT-2;
          pieces[y*GRID_COLS+x] = product;
          product.x = x*GRID_WIDTH; product.y = y*GRID_HEIGHT;
          addChild(product);
        }
      }
      if(_identify_imploding_pieces() == 0)
        break;
      else /* clear the board for refilling */
        for(int x=0; x < GRID_ROWS; ++x)
          for(int y=0; y < GRID_COLS; ++y)
            removeChild(pieces[y*GRID_COLS+x]);
    }

    addEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
    addEventListener(MouseEvent.MOUSE_UP, _onMouseUp);
    addEventListener(MouseEvent.MOUSE_MOVE, _onMouseMove);
  }

  void _onMouseUp(MouseEvent me) {
    if(gameState == PUSHING)
      gameState = WAITING;
  }

  void _onMouseDown(MouseEvent me) {
    if(gameState != WAITING)
      return;
    gameState = PUSHING;
    // Calculate position on grid
    int column = me.localX  ~/ GRID_WIDTH;
    int line = me.localY  ~/  GRID_HEIGHT;
    moveStart = new Point(column, line);
    moveStart_center = new Point(column*GRID_WIDTH+GRID_WIDTH/2, line*GRID_HEIGHT+GRID_HEIGHT/2);
  }

  void _onMouseMove(MouseEvent me) {
    if(gameState != PUSHING)
      return;
    // Calculate the delta to the startMove center
    Point mouse_pos = new Point(me.localX, me.localY);
    Point delta_p = mouse_pos.subtract(moveStart_center);
    int column = me.localX  ~/ GRID_WIDTH;
    int line = me.localY  ~/  GRID_HEIGHT;
    int distance = (column - moveStart.x).abs()+(line-moveStart.y).abs();
    if(distance > 1) // can only move one position
      return;
    moveEnd = new Point(column, line);
    if(delta_p.x.abs() > GRID_WIDTH/2) {
      startSwitch(moveStart.x, moveStart.y, column, line, true);
    }
    if(delta_p.y.abs() > GRID_HEIGHT/2) {
      startSwitch(moveStart.x, moveStart.y, column, line, true);
    }
  }

  void startSwitch(x1, y1, x2, y2, rollBack) {
    gameState = SWITCHING;
    Product product1 = pieces[y1*GRID_COLS+x1];
    Product product2 = pieces[y2*GRID_COLS+x2];
    var tween1 = new Tween(product1, 0.3, TransitionFunction.linear);
    tween1.animate.x.to(x2*GRID_WIDTH);
    tween1.animate.y.to(y2*GRID_HEIGHT);
    var tween2 = new Tween(product2, 0.3, TransitionFunction.linear);
    tween2.animate.x.to(x1*GRID_WIDTH);
    tween2.animate.y.to(y1*GRID_HEIGHT);
    tween2.onComplete = () => onProductSwitchComplete(rollBack);
    // Switch them on the board data
    pieces[y1*GRID_COLS+x1] = product2;
    pieces[y2*GRID_COLS+x2] = product1;
    _juggler.add(tween1);
    _juggler.add(tween2);
  }

  void onProductSwitchComplete(bool rollBack) {
    if(rollBack==false) {
      gameState = WAITING;
    } else {
      int implode_count = _identify_imploding_pieces();
      if(implode_count == 0) { // No implode generated, switch back products
        startSwitch(moveEnd.x, moveEnd.y, moveStart.x, moveStart.y, false);
      } else
        if(implodeLines() > 0)
          dropPieces();
    }
  }

  void dropPiece(x1, y1, x2, y2) {
    ++dropping_pieces;
    Product piece = pieces[y1*GRID_COLS+x1];
    pieces[y1*GRID_COLS+x1] = null;
    var tween = new Tween(piece, 0.5, TransitionFunction.linear);
    tween.animate.y.to(y2*GRID_HEIGHT);
    tween.onComplete = () => onDropPieceComplete(piece);
    _juggler.add(tween);
  }

  void onDropPieceComplete(Product piece) {
    int x = piece.x  ~/ GRID_WIDTH;
    int y = piece.y  ~/  GRID_HEIGHT;
    pieces[x+y*GRID_COLS] = piece;
    if(--dropping_pieces == 0) {
      if(implodeLines() > 0)
        dropPieces();
      else {
        gameState = WAITING;
      }
    }
  }

  void dropPieces() {
    /* Check for holes on the board and drop pieces */

    // Scan vertical  lines for holes
    _vLines.clear();
    for(int x=0; x < GRID_COLS; ++x) {
      int start_pos = 0;
      int line_len = 1;
      Product current_face;
      int col_drop_count = 0;
      // from bottom to top
      for(int y=GRID_ROWS-1; y > -1; --y) {
        current_face = pieces[y*GRID_COLS+x];
        if(current_face == null) {
            col_drop_count++;
            continue;
        }
        if(col_drop_count > 0) { // Holes below, drop it
          dropPiece(x, y, x, y+col_drop_count);
        }
      }
      // Drop more from the top
      for(int i=0; i<col_drop_count; ++i) {
        ++dropping_pieces;
        int face_id = 1 + _rng.nextInt(7);
        Product product = new Product(_resourceManager.getBitmapData('piece_$face_id'),face_id);
        product.width = GRID_WIDTH-2;
        product.height = GRID_HEIGHT-2;
        product.x = x*GRID_WIDTH;
        product.y = -(i+1)*GRID_HEIGHT;
        this.addChild(product);
        var tween = new Tween(product, 0.5, TransitionFunction.linear);
        tween.animate.y.to((col_drop_count-i-1)*GRID_HEIGHT);
        tween.onComplete = () => onDropPieceComplete(product);
        _juggler.add(tween);
      }
    }
  }

  void implodeHLine(element) {
    int y = element[0];
    int x = element[1];
    int len = element[2];
    print("Imploding line $element");
    for(int i=0; i < len; i++) {
      Product piece = pieces[y*GRID_COLS+x+i];
      pieces[x+i+y*GRID_COLS] = null;
      this.removeChild(piece);
    }
  }

  void implodeVLine(element) {
    int x = element[0];
    int y = element[1];
    int len = element[2];
    print("Imploding line $element");
    for(int i=0; i < len; i++) {
      Product piece = pieces[x+(y+i)*GRID_COLS];
      if(piece == null ) // piece crossing a V and H line
        continue;
      pieces[x+(y+i)*GRID_COLS] = null;
      this.removeChild(piece);
    }
  }

  int implodeLines() {
    int count = _identify_imploding_pieces();
    gameState = IMPLODING;
    for(final element in _hLines)
        implodeHLine(element);
    for(final element in _vLines)
        implodeVLine(element);
    return count;
  }

  int _identify_imploding_pieces() {
    // Scan horizontal lines for 3+ pieces of the same id
    _hLines.clear();
    for(int y=0; y < GRID_ROWS; ++y) {
      int start_pos = 0;
      int line_len = 1;
      int last_face = pieces[y*GRID_COLS].face_id;
      int current_face;
      String line = last_face.toString();
      for(int x=1; x < GRID_COLS; ++x) {
          current_face = pieces[y*GRID_COLS+x].face_id;
          line = "$line$current_face";
          if(current_face == last_face)
            ++line_len;
          else {
            if(current_face !=0 && line_len > 2)
              _hLines.add([y, start_pos, line_len]);
            start_pos = x;
            last_face = current_face;
            line_len = 1;
          }
      }
      // print('$line');
      if(current_face != 0 && line_len > 2)
        _hLines.add([y, start_pos, line_len]);
    }

    // Scan vertical  lines for 3+ pieces of the same id
    _vLines.clear();
    for(int x=0; x < GRID_COLS; ++x) {
      int start_pos = 0;
      int line_len = 1;
      int last_face = pieces[x].face_id;
      String line = last_face.toString();
      for(int y=1; y < GRID_ROWS; ++y) {
        int current_face = pieces[y*GRID_COLS+x].face_id;
        line = "$line$current_face";
        if(current_face == last_face)
          ++line_len;
        else {
          if(line_len > 2)
            _vLines.add([x, start_pos, line_len]);
          start_pos = y;
          last_face = current_face;
          line_len = 1;
        }
      }
      if(line_len > 2)
        _vLines.add([x, start_pos, line_len]);
    }
    return _hLines.length + _vLines.length;
  }
}