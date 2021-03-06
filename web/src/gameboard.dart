/* */
part of farmline;

const GRID_ROWS = 8;   // grid rows
const GRID_COLS = 8;   // grid columns
const GRID_WIDTH = 64;  // grid cell width
const GRID_HEIGHT = 64; // grid cell height



// game states
const WAITING = 0;      // Waiting for player move
const PUSHING = 1;      // Player is pushing a product
const SWITCHING = 2;    // Products are being switched
const IMPLODING = 3;    // Product lines beng imploded

const DROP_DURATION = 0.15;
const IMPLOSION_DURATION = 0.8;

class GameBoard extends DisplayObjectContainer {


  ResourceManager _resourceManager;
  Juggler _juggler;
  int gameState = WAITING;
  Point moveStart;
  Point moveStart_center;
  Point moveEnd;
  Shape _playBox = null;
  
  // The board grid is stored linearly, using a list
  // 2d positions must be translated to the linear positions
  // linear = y*GRID_ROWS+x
  
  List _cells = new List(GRID_ROWS*GRID_COLS);
  int movingCount = 0;
  List _hLines = new List(); // List of horizontal lines to be imploded
  List _vLines = new List();  // List of vertical lines to be imploded
  int dropping_products = 0;
  int implodding_count = 0;
  var _rng  = new math.Random();
  //ScoreBoard _scoreboard;
  
  GameBoard(ResourceManager resourceManager, Juggler juggler) {
    _resourceManager = resourceManager;
    _juggler = juggler;
    var background = new BitmapData(GRID_WIDTH*GRID_COLS, GRID_HEIGHT*GRID_ROWS,
        false, Color.BlanchedAlmond);
    var backgroundBitmap = new Bitmap(background);
    addChild(backgroundBitmap);
    //_scoreboard = new ScoreBoard(_resourceManager,  10);
    //addChild(_scoreboard);

    // Fill game board with random products
    // Loop until we generate a board with no initial imploding products
    while(true) {
      for(int x=0; x < GRID_ROWS; ++x) {
        for(int y=0; y < GRID_COLS; ++y) {
          int face_id = 1 + _rng.nextInt(5);
          BitmapData bitmap = resourceManager.getBitmapData('product_$face_id');
          Product product = new Product(bitmap,face_id)
           ..x = x*GRID_WIDTH
           ..y = y*GRID_HEIGHT;
          setGrid(x, y, product);         
          addChild(product);
        }
      }
      if(_identify_imploding_products() == 0)
        break;
      else /* clear the board for refilling */
        for(int x=0; x < GRID_ROWS; ++x)
          for(int y=0; y < GRID_COLS; ++y)
            removeChild(getGrid(x, y));
    }

    addEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
    addEventListener(MouseEvent.MOUSE_UP, _onMouseUp);
    addEventListener(MouseEvent.MOUSE_MOVE, _onMouseMove);
  }

  // Set a grid cell to value
  setGrid(x, y, value) => _cells[x+y*GRID_COLS] = value;
  
  // Return the value from cell
  getGrid(x, y) => _cells[x+y*GRID_COLS];

  void _onMouseUp(MouseEvent me) {
    if(_playBox != null) {
      removeChild(_playBox);
      _playBox = null;
    }    
    if(gameState == PUSHING) // The player is no longer pyshing
      gameState = WAITING;
  }

  void _onMouseDown(MouseEvent me) {
    if(gameState != WAITING) // Not in a playable state
      return;
    gameState = PUSHING;
    // Calculate position on grid
    int column = me.localX  ~/ GRID_WIDTH;
    int line = me.localY  ~/  GRID_HEIGHT;
    moveStart = new Point(column, line);
    moveStart_center = new Point(column*GRID_WIDTH+GRID_WIDTH/2, line*GRID_HEIGHT+GRID_HEIGHT/2);
    var shape = new Shape();
    
    shape.graphics
      ..beginPath()
      ..rect(column*GRID_WIDTH, line*GRID_HEIGHT, GRID_WIDTH-4, GRID_HEIGHT-4)
      ..strokeColor(Color.Black, 2);
    addChild(shape);
    _playBox = shape;

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
    if(_playBox != null) {
      removeChild(_playBox);
      _playBox = null;
    }
    gameState = SWITCHING;
    Product product1 = getGrid(x1, y1);
    Product product2 = getGrid(x2, y2);
    var tween1 = new Tween(product1, 0.3, TransitionFunction.linear);
    tween1.animate
      ..x.to(x2*GRID_WIDTH)
      ..y.to(y2*GRID_HEIGHT);
    var tween2 = new Tween(product2, 0.3, TransitionFunction.linear);
    tween2.animate
      ..x.to(x1*GRID_WIDTH)
      ..y.to(y1*GRID_HEIGHT);
    tween2.onComplete = () => onProductSwitchComplete(rollBack);
    // Switch them on the board data
    setGrid(x1, y1, product2);
    setGrid(x2, y2, product1);
    _juggler.add(tween1);
    _juggler.add(tween2);
  }

  void onProductSwitchComplete(bool rollBack) {
    if(rollBack==false) {
      gameState = WAITING;
    } else {
      int implode_count = _identify_imploding_products();
      if(implode_count == 0) { // No implode generated, switch back products
        startSwitch(moveEnd.x, moveEnd.y, moveStart.x, moveStart.y, false);
      } else
        implodeLines();
    }
  }

  // Sart the drop animation - animation time depends on how many cols to drop
  // Move a product to it's destination after dropping
  void dropProduct(x1, y1, x2, y2, col_drop_count) {
    ++dropping_products;
    Product product = getGrid(x1, y1);
    setGrid(x1, y1, null);
    var tween = new Tween(product, DROP_DURATION*col_drop_count, TransitionFunction.linear)
      ..animate.y.to(y2*GRID_HEIGHT)
      ..onComplete = () => onDropProductComplete(product);
    _juggler.add(tween);
  }

  void onDropProductComplete(Product product) {
    int x = product.x  ~/ GRID_WIDTH;
    int y = product.y  ~/  GRID_HEIGHT;
    setGrid(x, y, product);
    // If nothing more is dropping
    if(--dropping_products == 0) {
      // Check for new lines to be imploded
      if(implodeLines() == 0)
        // Set game for next play
        gameState = WAITING;
    }
  }

  void dropProducts() {
    /* Check for holes on the board and drop products */

    // Scan vertical  lines for holes
    _vLines.clear();
    for(int x=0; x < GRID_COLS; ++x) {
      int start_pos = 0;
      int line_len = 1;
      Product current_face;
      int col_drop_count = 0;
      // from bottom to top
      for(int y=GRID_ROWS-1; y > -1; --y) {
        current_face = getGrid(x, y);
        if(current_face == null) {
            col_drop_count++;
            continue;
        }
        if(col_drop_count > 0) { // Holes below, drop it
          dropProduct(x, y, x, y+col_drop_count, col_drop_count);
        }
      }
      
      // Drop from the top - animation time depends on how many cols to drop      
      for(int i=0; i<col_drop_count; ++i) {
        ++dropping_products;
        int face_id = 1 + _rng.nextInt(5);
        Product product = new Product(_resourceManager.getBitmapData('product_$face_id'),face_id)
          ..x = x*GRID_WIDTH
          ..y = -(i+1)*GRID_HEIGHT;
        this.addChild(product);
        var tween = new Tween(product, DROP_DURATION*col_drop_count, TransitionFunction.linear)
          ..animate.y.to((col_drop_count-i-1)*GRID_HEIGHT)
          ..onComplete = () => onDropProductComplete(product);
        _juggler.add(tween);
      }
    }
  }

  void onImplodeProductComplete(product) {
    removeChild(product);
    if(--implodding_count == 0)
      dropProducts();
  }

  // Implode lines previous identified by _identify_imploding_products()
  int implodeLines() {
    
    void implode_product(x,y) {
      implodding_count++;
      Product product = getGrid(x, y);
      setGrid(x, y, null);      
      //removeChild(product);
      var tween = new Tween(product, IMPLOSION_DURATION, TransitionFunction.easeInBack)
        //..animate.rotation.by(5)
        ..animate.alpha.to(0)
        ..animate.x.to((x*GRID_WIDTH+GRID_WIDTH/2) )//+200-_rng.nextInt(400))
        ..animate.y.to((y*GRID_HEIGHT+GRID_HEIGHT/2) )//+200-_rng.nextInt(400))
        ..animate.scaleX.to(0)
        ..animate.scaleY.to(0)
        ..onComplete = () => onImplodeProductComplete(product);
        ;
      _juggler.add(tween);        
    }

    int count = _identify_imploding_products();
    gameState = IMPLODING;
    
    // Implode horizontal lines
    for(final element in _hLines) {
      int y = element[0];
      int x = element[1];
      int len = element[2];
      print("Imploding line $element");
      for(int i=0; i < len; i++) {
        implode_product(x+i, y);
      }
      
    }
    for(final element in _vLines) {
      int x = element[0];
      int y = element[1];
      int len = element[2];
      print("Imploding line $element");
      for(int i=0; i < len; i++) {      
        Product product = getGrid(x, y+i);
        if(product == null ) // product crossing a V and H line
          continue;
        implode_product(x, y+i);
      }      
    }
    return count;
  }

  int _identify_imploding_products() {
    // Scan horizontal lines for 3+ products of the same id
    _hLines.clear();
    for(int y=0; y < GRID_ROWS; ++y) {
      int start_pos = 0;
      int line_len = 1;
      int last_face = getGrid(0, y).face_id;
      int current_face;
      String line = last_face.toString();
      for(int x=1; x < GRID_COLS; ++x) {
          current_face = getGrid(x, y).face_id;
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

    // Scan vertical  lines for 3+ products of the same id
    _vLines.clear();
    for(int x=0; x < GRID_COLS; ++x) {
      int start_pos = 0;
      int line_len = 1;
      int last_face = getGrid(x, 0).face_id;
      String line = last_face.toString();
      for(int y=1; y < GRID_ROWS; ++y) {
        int current_face = getGrid(x, y).face_id;
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