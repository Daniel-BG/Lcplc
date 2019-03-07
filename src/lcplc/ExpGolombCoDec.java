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
	
	//SAMPLE STUFF
	private boolean sampling = false;
	private Sampler<Integer> inputSampler;
	private Sampler<Long> codeSampler;
	private Sampler<Integer> quantSampler;
	
	public void startSampling() {
		sampling = true;
		inputSampler = new Sampler<Integer>();
		codeSampler  = new Sampler<Long>();
		quantSampler = new Sampler<Integer>();
	}
	
	public void endSampling(String inputSamplerFile, String codeSamplerFile, String quantSamplerFile) throws IOException {
		sampling = false;
		inputSampler.export(inputSamplerFile);
		codeSampler.export(codeSamplerFile);
		quantSampler.export(quantSamplerFile);
	}
	//END SAMPLE STUFF
	
	public void encode(int source, BitOutputStream bos) throws IOException {
		if (sampling) inputSampler.sample(source);
		
		int base = source / (1 << order) + 1;
		int baseBits = Utils.countBitsOf(base);
		int cnt = baseBits;
		
		if (sampling) codeSampler.sample((long)base);
		if (sampling) quantSampler.sample(cnt - 1 + baseBits);
		
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
