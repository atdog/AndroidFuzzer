package tw.dm4;

public final class BytesHelper {

  private BytesHelper() {}

  public static int toInt( byte[] bytes ) {
    int result = 0;
    for (int i=0; i<4; i++) {
      result = ( result << 8 ) + (int) bytes[i];
    }
    return result;
  }
  
}
