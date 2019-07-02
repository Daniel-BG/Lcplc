package lcplc.util;

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
	
	public static void changeEndianness(byte[] arr, int s0, int s1, int s2, int s3) {
		//change endianness
		for (int i = 0; i+3 < arr.length; i += 4) {
			byte[] tmp = new byte[4];
			tmp[0] = arr[i];
			tmp[1] = arr[i+1];
			tmp[2] = arr[i+2];
			tmp[3] = arr[i+3];
			// swap
			arr[i] 	 = tmp[s0];
			arr[i+1] = tmp[s1];
			arr[i+2] = tmp[s2];
			arr[i+3] = tmp[s3];
		}
	}
	
}
