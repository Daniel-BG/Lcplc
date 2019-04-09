package lcplc;

public interface Quantizer {
	/**
	 * @param value to be quantized
	 * @return the quantized value 
	 */
	public int quantize(int value);
	
	/**
	 * @param quantizedValue the value in the quantized domain
	 * @return an approximation of the original value
	 */
	public int dequantize(int qVal);

}
