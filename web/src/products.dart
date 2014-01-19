part of farmline;

class Product extends Bitmap implements Animatable {

    num vx, vy;
    int face_id;

    Product(BitmapData bitmapData, this.face_id):super(bitmapData) {
    }

    bool advanceTime(num time) {
      // Nothing specal
    }
}