package lcplc;

import java.io.IOException;

import com.jypec.util.bits.Bit;
import com.jypec.util.bits.BitInputStream;
import com.jypec.util.bits.BitOutputStream;
import com.jypec.util.bits.BitStreamConstants;


/**
 * Implements a Golomb coder/decoder with parameter equal to a power of two
 * @author Daniel
 *
 */
public class GolombCoDec {
	
	int powerOfTwo = 0;
	int parameter = 1;
	
	/**
	 * Instantiate a Golomb Coder/Decoder with parameter 2^powerOfTwo
	 * @param powerOfTwo
	 */
	public GolombCoDec(int powerOfTwo) {
		this.setParameter(powerOfTwo);
	}
	
	public void setParameter(int powerOfTwo) {
		this.powerOfTwo = powerOfTwo;
		this.parameter  = 1 << powerOfTwo;
	}
	
	/**
	 * Wrapper for {@link #setParameter(int)} and {@link #encode(int, BitOutputStream)}
	 */
	public void encode(int powerOfTwo, int value, BitOutputStream bos) throws IOException {
		if (sampling) inputDataSampler.sample(value);
		if (sampling) inputParameterSampler.sample(powerOfTwo);
		
		this.setParameter(powerOfTwo);
		this.encode(value, bos);
	}

	/**
	 * Encode the given value and output its bit representation in the given BitOutputStream
	 * @param value
	 * @param bos
	 * @throws IOException
	 */
	public void encode(int value, BitOutputStream bos) throws IOException {
		int quotient = value / this.parameter;
		int remainder = value % this.parameter;
		
		//System.out.print(">" + quotient + ":" + this.powerOfTwo);
		if (quotient > MAX_QUOT) {
			MAX_QUOT = quotient;
			System.out.println(MAX_QUOT);
		}
		
		//mimic the hardware behavior
		while (quotient >= 32) {
			bos.writeBits(-1, 32, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
			quotient -= 32;
			if (sampling) codeSampler.sample(-1l);
			if (sampling) quantSampler.sample(32);
		}
		if (quotient >= 16) {
			bos.writeBits(-1, quotient, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
			if (sampling) codeSampler.sample(-1l);
			if (sampling) quantSampler.sample(quotient);
			quotient = 0;
		}
		
		bos.writeBits((-1) << 1, quotient + 1, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		bos.writeBits(remainder, this.powerOfTwo, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		
		if (sampling) codeSampler.sample(((-1l) << (this.powerOfTwo + 1)) | (long) remainder);
		if (sampling) quantSampler.sample(quotient + 1 + this.powerOfTwo);
		//end mimicking hardware behavior
		
		/*write quotient
		while (quotient --> 0)
			bos.writeBit(Bit.BIT_ONE);
		bos.writeBit(Bit.BIT_ZERO);
		
		bos.writeBits(remainder, this.powerOfTwo, BitStreamConstants.ORDERING_LEFTMOST_FIRST);*/
	}
	
	private static int MAX_QUOT = 0;
	
	/**
	 * Wrapper for {@link #setParameter(int)} and {@link #decode(BitInputStream)}
	 */
	public int decode(int powerOfTwo, BitInputStream bis) throws IOException {
		this.setParameter(powerOfTwo);
		return this.decode(bis);
	}
	
	/**
	 * Decode the next golomb-coded value in the given BitInputStream according
	 * to this GolombCoDec's parameters
	 * @param bis
	 * @return
	 * @throws IOException
	 */
	public int decode(BitInputStream bis) throws IOException {
		int quotient = 0;
		while (bis.readBitAsInt() != 0) {
			quotient++;
		}
		
		int remainder = bis.readBits(this.powerOfTwo, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		
		return quotient * this.parameter + remainder;
	}
	
	
	
	//SAMPLE STUFF
	private boolean sampling = false;
	private Sampler<Integer> inputDataSampler;
	private Sampler<Integer> inputParameterSampler;
	private Sampler<Long> codeSampler;
	private Sampler<Integer> quantSampler;
	
	public void startSampling() {
		sampling = true;
		inputDataSampler = new Sampler<Integer>();
		inputParameterSampler = new Sampler<Integer>();
		codeSampler  = new Sampler<Long>();
		quantSampler = new Sampler<Integer>();
	}
	
	public void endSampling(String inputDataSamplerFile, String inputParameterSamplerFile, String codeSamplerFile, String quantSamplerFile) throws IOException {
		sampling = false;
		inputDataSampler.export(inputDataSamplerFile);
		inputParameterSampler.export(inputParameterSamplerFile);
		codeSampler.export(codeSamplerFile);
		quantSampler.export(quantSamplerFile);
	}
	//END SAMPLE STUFF
}
