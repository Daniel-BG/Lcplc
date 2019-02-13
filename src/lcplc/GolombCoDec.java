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
		//write quotient
		while (quotient --> 0)
			bos.writeBit(Bit.BIT_ONE);
		bos.writeBit(Bit.BIT_ZERO);
		

		
		bos.writeBits(remainder, this.powerOfTwo, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
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
	
	
}
