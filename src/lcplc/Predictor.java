package lcplc;

public class Predictor {

	public static int basic2DPrediction(int[][] matrix, int xpos, int ypos) {
		int prediction = 0;
		if (xpos == 0 && ypos == 0) {
			throw new IllegalArgumentException("Cannot predict first sample");
		} else if (xpos == 0) {
			prediction = matrix[xpos][ypos-1];
		} else if (ypos == 0) {
			prediction = matrix[xpos-1][ypos];
		} else {
			prediction = matrix[xpos-1][ypos] + matrix[xpos][ypos-1];
			prediction /= 2;
		}
		return prediction;
	}
	
}
