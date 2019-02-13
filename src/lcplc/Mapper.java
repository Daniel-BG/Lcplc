package lcplc;

public class Mapper {

	public static int mapError(int error) {
		return error > 0 ? (2*error - 1) : (-2*error);
	}
	
	public static int unmapError(int mappedError) {
		int error;
		if (mappedError % 2 == 0) {
			error = -mappedError / 2;
		} else {
			error = (mappedError + 1) / 2;
		}
		return error;
	}
	
}
