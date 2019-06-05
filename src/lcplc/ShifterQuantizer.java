package lcplc;

public class ShifterQuantizer implements Quantizer {
	
	private int downscale;
	private int addition;
	
	public ShifterQuantizer(int downscale) {
		if (downscale < 0) {
			throw new IllegalArgumentException();
		}
		
		this.downscale = downscale;
		if (downscale == 0)
			this.addition = 0;
		else
			this.addition  = 1 << (downscale - 1);
	}

	@Override
	public int quantize(int value) {
		//int qVal = (Math.abs(value) + this.addition) >> this.downscale;
		//return value > 0 ? qVal : -qVal;
		return (value + this.addition) >> this.downscale;
	}

	@Override
	public int dequantize(int qVal) {
		//int absQVal = qVal > 0 ? qVal : -qVal;
		//int val = absQVal << this.downscale;
		//return qVal > 0 ? val : -val;
		return qVal << this.downscale;
	}

}
