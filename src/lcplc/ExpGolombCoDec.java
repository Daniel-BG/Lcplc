package lcplc;

import java.io.IOException;

import com.jypec.util.bits.Bit;
import com.jypec.util.bits.BitInputStream;
import com.jypec.util.bits.BitOutputStream;
import com.jypec.util.bits.BitStreamConstants;

/**
 * Create an Exponential Golomb Coder/Decoder
 * @author Daniel
 *
 */
public class ExpGolombCoDec {
	
	private int order;
	
	public ExpGolombCoDec(int order) {
		this.order = order;
	}
	
	public ExpGolombCoDec() {
		this(0);
	}
	
	public void encode(int source, BitOutputStream bos) throws IOException {
		int base = source / (1 << order) + 1;
		int baseBits = Utils.countBitsOf(base);
		int cnt = baseBits;
		while(cnt-->1)
			bos.writeBit(Bit.BIT_ZERO);
		bos.writeBits(base, baseBits, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		
		if (order > 0) {
			int offset = base % (1 << order);
			bos.writeBits(offset, order, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		}
	}
	
	public int decode(BitInputStream bis) throws IOException {
		int baseBits = 0;
		int firstBit = 0;
		while (firstBit == 0) {
			baseBits++;
			firstBit = bis.readBitAsInt();
		}
		int base = (1 << (baseBits - 1)) + bis.readBits(baseBits - 1, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		int offset = 0;
		if (order > 0) {
			offset = bis.readBits(order, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
		}
		int res = (base - 1) * (1 << order) + offset;
		return res;
	}
	

}
