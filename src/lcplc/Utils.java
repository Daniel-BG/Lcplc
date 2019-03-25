package lcplc;

public class Utils {
	
	public static long sumArray(int[][] array, int xmx, int ymx) {
		long acc = 0;
		for (int x = 0; x < xmx; x++) {
			for (int y = 0; y < ymx; y++) {
				acc += array[x][y];
			}
		}
		return acc;
	}

	
	
	public static int countBitsOf(int val) {
		int ret = 0;
		while(0 < val) {
			ret++;
			val>>=1;
		}
		return ret;
	}
	
	
	
	public static int clamp(int val, int min, int max) {
		return val < min ? min : (val > max ? max : val);
	}
}
