

package lcplc;

public class IntegerUniformThresholdQuantizer {
	
	private int downscale;
	private int upscale;
	
	/**
	 * Create a Uniform threshold Quantizer that works on integers
	 * with only integer operations, avoiding divisions in favor of greater
	 * performance. <br>
	 * The quantized value Q is calculated from the original value q as: <br>
	 * Q = sign(q)*max(0, round(abs(q)*upscale/(2*downscale))) 
	 * <br>
	 * In a normal UTQ we follow the equation: <br>
	 * Q = sign(q)*max(0, round(abs(q)/(2*delta))) <br>
	 * So here we have: delta = downscale/upscale;
	 * @param downscale
	 * @param upscale
	 */
	public IntegerUniformThresholdQuantizer(int downscale, int upscale) {
		this.downscale = downscale;
		this.upscale = upscale;
	}
	
	/**
	 * @param value to be quantized
	 * @return the quantized value according to this quantizer parameters set via {@link #IntegerUniformThresholdQuantizer(int, int)}
	 */
	public int quantize(int value) {
		int qVal = (Math.abs(value)*this.upscale + this.downscale) / (2*this.downscale);
		return value > 0 ? qVal : -qVal;
	}
	
	
	/**
	 * @param quantizedValue the value in the quantized domain
	 * @return an approximation of the original value which error will depend on {@link #IntegerUniformThresholdQuantizer(int, int)} configuration
	 */
	public int dequantize(int qVal) {
		int absQVal = qVal > 0 ? qVal : -qVal;
		int val = (absQVal*2*this.downscale) / this.upscale;
		return qVal > 0 ? val : -val;
	}

}
