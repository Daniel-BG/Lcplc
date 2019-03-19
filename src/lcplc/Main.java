package lcplc;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.util.Map.Entry;

import com.jypec.img.HeaderConstants;
import com.jypec.img.HyperspectralImage;
import com.jypec.img.HyperspectralImageData;
import com.jypec.util.bits.Bit;
import com.jypec.util.bits.BitInputStream;
import com.jypec.util.bits.BitOutputStream;
import com.jypec.util.bits.BitStreamConstants;
import com.jypec.util.io.HyperspectralImageReader;

public class Main {

	//USE THIS SINCE ITS DATA TYPE 12: UNSIGNED TWO BYTE!!
	static String input = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.dat";
	static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.hdr";
	static String samplerBaseDir = "C:/Users/Daniel/Repositorios/Lcplc/test_data/";
	static String sampleExt = ".smpl";


	public static void main(String[] args) {
		//clear directory
		File dir = new File(samplerBaseDir);
		
		for(File file: dir.listFiles()) {
		    if (!file.isDirectory()) 
		        if (!file.delete())
		        	System.out.println("Problem deleting file: " + file.getPath());
		}
		
		Compressor c = new Compressor();
		c.test();
	}
	

	public static class Compressor {
		
		private static final int CONST_ACC_QUANT = 32;
		//delta = down/up
		private static final int CONST_UTQ_UPSCALE = 2;
		private static final int CONST_UTQ_DOWNSCALE = 1;
		//set gamma to zero to avoid block skipping
		private static final int CONST_GAMMA = 0;
		
		
		private static final int BLOCKS_TO_CODE = 3;
		private static final int MAX_LINES_PER_BLOCK = 16;
		private static final int MAX_SAMPLES_PER_BLOCK = 16;
		
		
		public void test() {
			HyperspectralImage hi;
			try {
				hi = HyperspectralImageReader.read(input, inputHeader, true);
				for (Entry<HeaderConstants, Object> e: hi.getHeader().entrySet()) {
					System.out.print(e.getKey().toString() + ": " + e.getValue().toString() + "\n");
				};
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				return;
			}
			
			HyperspectralImageData hid = hi.getData();
			
			int imgBands	= hid.getNumberOfBands();
			int imgLines	= hid.getNumberOfLines();
			int imgSamples	= hid.getNumberOfSamples();
			
			ByteArrayOutputStream adbaos = new ByteArrayOutputStream();
			BitOutputStream bos = new BitOutputStream(adbaos);
			
			int compressedBlocks = 0;
			for (int l = 0; l < imgLines; l += MAX_LINES_PER_BLOCK) {
				for (int s = 0; s < imgSamples; s += MAX_SAMPLES_PER_BLOCK) {
					int blockBands = imgBands;
					int blockLines = Math.min(MAX_LINES_PER_BLOCK, imgLines - l);
					int blockSamples = Math.min(MAX_SAMPLES_PER_BLOCK, imgSamples - s);
					
					//fill block up
					int[][][] block = new int[blockBands][blockLines][blockSamples];
					for (int bb = 0; bb < blockBands; bb++) {
						for (int ll = 0; ll < blockLines; ll++) {
							for (int ss = 0; ss < blockSamples; ss++) {
								block[bb][ll][ss] = hid.getValueAt(bb, ll+l, ss+s);
							}
						}
					}
					//compress block
					try {
						this.compress(block, blockBands, blockLines, blockSamples, bos);
					} catch (IOException e) {
						e.printStackTrace();
						System.exit(0);
					}
					System.out.println("COMPR:  " + bos.getBitsOutput());
					compressedBlocks++;
					if (compressedBlocks >= BLOCKS_TO_CODE)
						break;
				}
				if (compressedBlocks >= BLOCKS_TO_CODE)
					break;
			}
			
			try {
				bos.paddingFlush();
			} catch (IOException e1) {
				e1.printStackTrace();
				System.exit(0);
			}
			
			ByteArrayInputStream adbais = new ByteArrayInputStream(adbaos.toByteArray());
			BitInputStream bis = new BitInputStream(adbais);
			
			int unCompressedBlocks = 0;
			for (int l = 0; l < imgLines; l += MAX_LINES_PER_BLOCK) {
				for (int s = 0; s < imgSamples; s += MAX_SAMPLES_PER_BLOCK) {
					int blockBands = imgBands;
					int blockLines = Math.min(MAX_LINES_PER_BLOCK, imgLines - l);
					int blockSamples = Math.min(MAX_SAMPLES_PER_BLOCK, imgSamples - s);
					
					//uncompress block
					try {
						this.uncompress(blockBands, blockLines, blockSamples, bis);
					} catch (IOException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
						System.exit(0);
					}

					System.out.println("UNCOMPR:  " + bis.getBitsInput());
					unCompressedBlocks++;
					if (unCompressedBlocks >= BLOCKS_TO_CODE)
						break;
				}
				if (unCompressedBlocks >= BLOCKS_TO_CODE)
					break;
			}
			
			
			//output bytes
			Sampler<Integer> outputSampler = new Sampler<Integer>("output");
			
			byte[] bytesoutput = adbaos.toByteArray();
			for (int i = 0; i < bytesoutput.length; i+=4) {
				if (i + 3 >= bytesoutput.length)
					break;
				int word = ((bytesoutput[i]   << 24) & 0xff000000) 
						 | ((bytesoutput[i+1] << 16) & 0x00ff0000) 
						 | ((bytesoutput[i+2] << 8 ) & 0x0000ff00) 
						 | ((bytesoutput[i+3]      ) & 0x000000ff);
				outputSampler.sample(word);
			}
			try {
				outputSampler.export();
			} catch (IOException e) {
				e.printStackTrace();
				System.exit(0);
			}
			
		}
		
		
		public void compress(int[][][] block, int bands, int lines, int samples, BitOutputStream bos) throws IOException {
			Sampler.setSamplePath(samplerBaseDir);
			Sampler.setSampleExt(sampleExt);
			//samplers for testing in verilog/vhdl
			Sampler<Integer> xFirstBand		    = new Sampler<Integer>("x_firstband");
			Sampler<Integer> xTildeFirstBand	= new Sampler<Integer>("xtilde_firstband"); 
			Sampler<Integer> xFirstBand_last_r  = new Sampler<Integer>("x_firstband_last_r");
			Sampler<Integer> xFirstBand_last_s  = new Sampler<Integer>("x_firstband_last_s");
			
			Sampler<Integer> xOtherBands  		= new Sampler<Integer>("x_otherbands");
			Sampler<Integer> xhatSampler 		= new Sampler<Integer>("xhat");
			Sampler<Integer> xhat_last_s		= new Sampler<Integer>("xhat_last_s");
			Sampler<Long>    xmeanSampler		= new Sampler<Long>("xmean");
			Sampler<Long>    xhatmeanSampler	= new Sampler<Long>("xhatmean");
			Sampler<Integer> alphaSampler		= new Sampler<Integer>("alpha");
			
			Sampler<Integer> xTildeOtherBands   = new Sampler<Integer>("xtilde_otherbands");
			Sampler<Integer> xTilde_o_last_s    = new Sampler<Integer>("xtilde_others_last_s");
			
			Sampler<Integer> xSampler			= new Sampler<Integer>("x");
			Sampler<Integer> xSampler_last_s	= new Sampler<Integer>("x_last_s");
			Sampler<Integer> xSampler_last_b	= new Sampler<Integer>("x_last_b");
			Sampler<Integer> xSampler_last_i	= new Sampler<Integer>("x_last_i");
			
			Sampler<Integer> xtildeSampler		= new Sampler<Integer>("xtilde");
			Sampler<Integer> xtilde_last_s      = new Sampler<Integer>("xtilde_last_s");
			
			Sampler<Integer> mappedErrorSampler = new Sampler<Integer>("merr");
			Sampler<Integer> kjSampler			= new Sampler<Integer>("kj");
			
			Sampler<Integer> xhatrawSampler 	= new Sampler<Integer>("xhatraw");
			Sampler<Integer> xhatraw_last_s		= new Sampler<Integer>("xhatraw_last_s");
			Sampler<Integer> xhatraw_last_b		= new Sampler<Integer>("xhatraw_last_b");
			
			Sampler<Integer> dFlagSampler		= new Sampler<Integer>("dflag");
			
			
			//Sampler<Long>	 samplerHelper1		= new Sampler<Long>("helper1");
			//Sampler<Long>	 samplerHelper2		= new Sampler<Long>("helper2");
			//Sampler<Long>	 samplerHelper3		= new Sampler<Long>("helper3");		
			
			
			
			
			Sampler<Integer> errorSampler		= new Sampler<Integer>("error");
			
	
			
			
			int[][][] decodedBlock = new int[bands][lines][samples];
			
			ExpGolombCoDec expGolombZero = new ExpGolombCoDec(0);
			GolombCoDec golombCoDec = new GolombCoDec(0);
			Accumulator acc = new Accumulator(CONST_ACC_QUANT);
			IntegerUniformThresholdQuantizer iutq = new IntegerUniformThresholdQuantizer(CONST_UTQ_DOWNSCALE, CONST_UTQ_UPSCALE);
			
			
			expGolombZero.startSampling("egz_input", "egz_code", "egz_quant");
			golombCoDec.startSampling("gc_input", "gc_param", "gc_code", "gc_quant");
			
			//compress first band
			int[][] band = block[0];
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {	
					//First sample is just coded raw since we have not initialized
					//the counters/accumulators/predictors yet
					int error = 0;
					int mappedError;
					int prediction;
					int kj = 0;
					if (l == 0 && s == 0) {
						/*expGolombZero.encode(block[0][l][s], bos);
						//mimic hw by injecting here the first sample
						mappedError = block[0][l][s]; //Mapper.mapError(block[0][l][s]); 
						prediction = 0;
						
						decodedBlock[0][l][s] = block[0][l][s];
						acc.add(0);*/
						
						int quant = iutq.quantize(block[0][l][s]);
						int dequant = iutq.dequantize(quant);
						
						mappedError = Mapper.mapError(quant); //Mapper.mapError(block[0][l][s]);
						
						
						expGolombZero.encode(mappedError, bos);
						//mimic hw by injecting here the first sample
						 
						prediction = 0;
						
						decodedBlock[0][l][s] = dequant;
						acc.add(dequant);
						
					//For every other sample, code following
					//the predictive scheme
					} else {
						prediction = Predictor.basic2DPrediction(decodedBlock[0], l, s);
						
						
						error = block[0][l][s] - (int) prediction;
						int qErr  = iutq.quantize(error);
						error 	  = iutq.dequantize(qErr);
						decodedBlock[0][l][s] = (int) prediction + error;

						kj = findkj(acc);
						
						//code mapped error
						mappedError = Mapper.mapError(qErr);
						golombCoDec.encode(kj, mappedError, bos);	//encode the error
						acc.add(Math.abs(error));		//update Rj after coding
					}
					
					xFirstBand.sample(block[0][l][s]);
					xTildeFirstBand.sample(prediction);
					xFirstBand_last_r.sample(s == samples-1 ? 1 : 0);
					xFirstBand_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
					
					xSampler.sample(block[0][l][s]);
					xSampler_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
					xSampler_last_b.sample(s == samples-1 && l == lines-1 && 0 == bands-1 ? 1 : 0);
					xSampler_last_i.sample(0);
					
					xtildeSampler.sample(prediction);
					xtilde_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
					
					mappedErrorSampler.sample(mappedError);
					if (s != samples-1 || l != lines-1) kjSampler.sample(findkj(acc));
					
					xhatrawSampler.sample(decodedBlock[0][l][s]);
					xhatraw_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
					xhatraw_last_b.sample(s == samples-1 && l == lines-1 && 0 == bands-1 ? 1 : 0);
					
					
					errorSampler.sample(error);
				}
			}
			
			//calculate distortion threshold
			long sampleCnt = lines*samples;
			double delta = (double) CONST_UTQ_DOWNSCALE / (double) CONST_UTQ_UPSCALE;
			double thres = (double) CONST_GAMMA * delta * delta * sampleCnt * sampleCnt / 3.0;
			
			dFlagSampler.sample(1); //first sample should be 1 to save xhatraw samples instead of empty values
			
			//compress rest of bands
			for (int b = 1; b < bands; b++) {
				band = block[b];
				//generate means. we'll see where these means have to be from
				long currAcc = Utils.sumArray(band, lines, samples);
				long prevAcc = Utils.sumArray(decodedBlock[b-1], lines, samples);
				//sample the decoded block
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						xOtherBands.sample(block[b][l][s]);
						xhatSampler.sample(decodedBlock[b-1][l][s]);
						xhat_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
					}
				}
				xmeanSampler.sample(currAcc/sampleCnt);
				xhatmeanSampler.sample(prevAcc/sampleCnt);
				
				//generate alpha value. Could try to generate it using the original band as well to see performance
				long simpleAlphaNacc = 0;
				long simpleAlphaDacc = 0;
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						simpleAlphaNacc += (decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*(band[l][s] 			  - currAcc/sampleCnt);
						simpleAlphaDacc += (decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*(decodedBlock[b-1][l][s] - prevAcc/sampleCnt);
					}
				}
				
				//allocate 10 bits for alpha (when using it we need to divide by 512
				//to stay in the [0, 2) range
				int simpleAlphaScaled = findAlpha(simpleAlphaNacc, simpleAlphaDacc, 10);
				alphaSampler.sample(simpleAlphaScaled);
				long alphaScaleVal = 9; //512;
				//mu is 16 bits wide, and should stay that way since we are averaging 16-bit values
				long muScaled = currAcc / sampleCnt;
				
				bos.writeBits((int) simpleAlphaScaled, 10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				bos.writeBits((int) muScaled, 16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);


				//save encoding data in these variables and only add
				//it if we don't skip the block
				int[][] savedMappedError = new int[lines][samples];
				int[][] savedGolombParam = new int[lines][samples];
				int[][] savedPrediction  = new int[lines][samples];
				//initialize values for block compression
				long distortionAcc = 0;
				acc.reset(); 
				int[][] savedxhat = new int[lines][samples];
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						long prediction = muScaled + (((decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*simpleAlphaScaled)>>alphaScaleVal);
						savedPrediction[l][s] = (int) prediction;
						
						int error = band[l][s] - (int) prediction;
						distortionAcc += error*error;
						
						//quantize error and replace it with the
						//unquantized version since this is the one
						//the decoder will have
						int qErr  = iutq.quantize((int) error);
						error 	  = iutq.dequantize(qErr);
						long mappedError = Mapper.mapError(qErr);
						savedMappedError[l][s] = (int) mappedError;
						
						savedxhat[l][s] = (int) prediction + (int) error;
						
						if (l != 0 || s != 0) {
							savedGolombParam[l][s] = findkj(acc);
						}
						acc.add(Math.abs(error));		//update Rj after coding
						
						xTildeOtherBands.sample((int) prediction);
						xTilde_o_last_s.sample(l == lines-1 && s == samples-1 ? 1 : 0);
						
						xSampler.sample(block[b][l][s]);
						xSampler_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						xSampler_last_b.sample(s == samples-1 && l == lines-1 && b == bands-1 ? 1 : 0);
						xSampler_last_i.sample(0);
						
						xtildeSampler.sample((int) prediction);
						xtilde_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						
						mappedErrorSampler.sample((int)mappedError);
						if (s != samples-1 || l != lines-1) kjSampler.sample(findkj(acc));
						
						xhatrawSampler.sample(savedxhat[l][s]);
						xhatraw_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						xhatraw_last_b.sample(s == samples-1 && l == lines-1 && b == bands-1 ? 1 : 0);

						
						
						
						errorSampler.sample(error);
					}
				}
				
				if (distortionAcc > thres) {
					dFlagSampler.sample(1);
					bos.writeBit(Bit.BIT_ONE);
					//code block as normal
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = savedxhat[l][s];
							if (l == 0 && s == 0) {
								expGolombZero.encode(savedMappedError[l][s], bos);
							} else {
								golombCoDec.encode(savedGolombParam[l][s], savedMappedError[l][s], bos);	//encode the error
							}
						}
					}
				} else {
					dFlagSampler.sample(0);
					bos.writeBit(Bit.BIT_ZERO);
					//skip block
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = savedPrediction[l][s];
						}
					}
				}

				
				//System.out.println("Distortion is: " + distortionAcc + " (block was skipped: " + (distortionAcc <= thres) + ")");
			}
			
			//samplers for testing in verilog/vhdl
			xFirstBand.export();
			xTildeFirstBand.export(); 
			xFirstBand_last_r.export();
			xFirstBand_last_s.export();
			
			xOtherBands.export();
			xhatSampler.export();
			xhat_last_s.export();
			
			alphaSampler.export();
			xmeanSampler.export();
			xhatmeanSampler.export();
			
			xTildeOtherBands.export();
			xTilde_o_last_s.export();
			
			xSampler.export();
			xSampler_last_s.export();
			xSampler_last_b.export();
			xSampler_last_i.export();
			
			xtildeSampler.export();
			xtilde_last_s.export();
			
			mappedErrorSampler.export();
			kjSampler.export();

			xhatrawSampler.export();
			xhatraw_last_s.export();
			xhatraw_last_b.export();
			
			dFlagSampler.export();
			
			
			
			errorSampler.export();
			
			expGolombZero.endSampling();
			golombCoDec.endSampling();
		}
		
		public int findAlpha(long alphaN, long alphaD, long depth) {
			//resize alphas to make sure division of small numbers still yields an acceptable result
			alphaN <<= depth;
			alphaD <<= depth;
			
			//find alpha in [0, 2**depth) such that alphaD*alpha>>(depth-1) is closest to alphaN (in absolute value)
			
			int result = 0;
			for (int i = 0; i < depth; i++) {
				result <<= 1;
				if (alphaN >= alphaD) {
					alphaN -= alphaD;
					result += 1;
				}
				alphaD >>= 1;
			}
			
			/*long difference = Long.MAX_VALUE;
			int alphaRange = 1 << depth;
			for (int i = 0; i < alphaRange; i++) {
				long candidate = (alphaD*i)>>(depth-1);
				long localDiff = Math.abs(alphaN-candidate);
				if (localDiff < difference) {
					difference = localDiff;
					result = i;
				}
			}*/
			//System.out.println("Diff is: " + difference);
			return result;
		}
		
		
		public int findkj(Accumulator acc) {
			/*int Rj = (int) acc.getRunningSum();		//running count of last (at most) 32 mapped errors
			int J  =       acc.getRunningCount();	//number of samples to average out for golomb param calculation			
			int kj;									//will be the golomb parameter to code current mapped error
			for (kj = 0; (J<<kj) <= Rj; kj++);		//calculate kj
			
			return kj;*/
			

			
			int Rj = (int) acc.getRunningSum();	//running count of last (at most) 32 mapped errors
			int J  =       acc.getRunningCount();	//number of samples to average out for golomb param calculation			
			int kj = Utils.countBitsOf(J);
			kj = Rj >> kj;
			kj = Utils.countBitsOf(kj) + 1;
			return kj;
		}
		
		
		
		
		public int[][][] uncompress(int bands, int lines, int samples, BitInputStream bis) throws IOException {
			int[][][] decodedBlock = new int[bands][lines][samples];
			
			ExpGolombCoDec expGolombZero = new ExpGolombCoDec(0);
			GolombCoDec golombCoDec = new GolombCoDec(0);
			Accumulator acc = new Accumulator(CONST_ACC_QUANT);
			IntegerUniformThresholdQuantizer iutq = new IntegerUniformThresholdQuantizer(CONST_UTQ_DOWNSCALE, CONST_UTQ_UPSCALE);
			
			//decompress first band
			int[][] decodedBand = decodedBlock[0];
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {
					if (l == 0 && s == 0) {
						/*decodedBand[l][s] = expGolombZero.decode(bis);
						acc.add(0);*/
						int mappedErr = expGolombZero.decode(bis);
						int quant = Mapper.unmapError(mappedErr);
						int dequant = iutq.dequantize(quant);
						decodedBlock[0][l][s] = dequant;
						acc.add(dequant);
					} else {
						int prediction = Predictor.basic2DPrediction(decodedBand, l, s);
						
						//decode mapped error
						int kj = findkj(acc);
						
						int mappedError = golombCoDec.decode(kj, bis);
						int qErr = Mapper.unmapError(mappedError);
						int error = iutq.dequantize(qErr);
						//quantize error if necessary (losing information)
						decodedBlock[0][l][s] = prediction + error;
						acc.add(Math.abs(error));		//update Rj after coding
					}
				}		
			}
			
			//decompress rest of bands
			for (int b = 1; b < bands; b++) {
				//generate means
				long prevAcc = 0;
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						prevAcc += decodedBlock[b-1][l][s];
					}
				}

				//generate alpha value. Could try to generate it using the original band as well to see performance
				long sampleCnt = lines*samples;
				
				long simpleAlphaScaled = bis.readBits(10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				long alphaScaleVal = 9; //512;
				long muScaled = bis.readBits(16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				
				//is this block skipped or not?
				boolean coded = bis.readBoolean();

				acc.reset(); 
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						long prediction = muScaled + (((decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*simpleAlphaScaled)>>alphaScaleVal);
						
						if (coded) {
							int mappedError;
							if (l == 0 && s == 0) {
								mappedError = expGolombZero.decode(bis);
							} else {		
								int kj = findkj(acc);
								
								mappedError = golombCoDec.decode(kj, bis);
							}
							
							int qErr = Mapper.unmapError(mappedError);
							int error = iutq.dequantize(qErr);
							
							decodedBlock[b][l][s] = (int) prediction + error;
							acc.add(Math.abs(error));		//update Rj after coding
						} else {
							decodedBlock[b][l][s] = (int) prediction;
						}
					}
				}
			}
			
			return decodedBlock;
		}
	}	
}


/**
 * 
 * 		public void compress(int[][][] block, int bands, int lines, int samples) {
			long[][][] decodedBlock = new long[bands][lines][samples];
			long[][][] decodedBlockInt = new long[bands][lines][samples];
			
			//compress first band
			int[][] band = block[0];
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {
					if (l == 0 && s == 0) {
						//code first sample
						System.out.println("Coding first: " + band[l][s]);
						decodedBlock[0][l][s] = band[l][s];
						decodedBlockInt[0][l][s] = band[l][s];
					} else {
						int prediction = 0;
						if (l == 0) {
							prediction = band[l][s-1];
						} else if (s == 0) {
							prediction = band[l-1][s];
						} else {
							prediction = band[l-1][s] + band[l][s-1];
							prediction /= 2;
						}
						
						int error = band[l][s] - prediction;
						//quantize error if necessary
						decodedBlock[0][l][s] = prediction + error;
						decodedBlockInt[0][l][s] = prediction + error;
						
						//code mapped error
						int mappedError = error > 0 ? (2*error - 1) : (-2*error);
						//System.out.println("Coding value (" + l + "," + s + "): " + mappedError + " (original: " + band[l][s] + ")");
						 
					}
				}		
			}
			
			//compress rest of bands
			for (int b = 1; b < bands; b++) {
				band = block[b];
				
				//generate means. we'll see where these means have to be from
				long currAcc = 0;
				long prevAcc = 0;
				double currMean = 0;
				double prevMean = 0;
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						currAcc += band[l][s];
						prevAcc += decodedBlockInt[b-1][l][s];
						currMean += band[l][s];
						prevMean += decodedBlock[b-1][l][s];
					}
				}
				currMean /= (double) (lines*samples);
				prevMean /= (double) (lines*samples);
				
				//System.out.println("Accs are: " + currAcc + "," + prevAcc + "    " + currMean + "," + prevMean);
				
				//generate alpha value. Could try to generate it using the original band as well to see performance
				long alphaNAcc = 0;
				long alphaDAcc = 0;
				long simpleAlphaNacc = 0;
				long simpleAlphaDacc = 0;
				long sampleCnt = lines*samples;
				double alphaN = 0;
				double alphaD = 0;
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						alphaNAcc += ( decodedBlockInt[b-1][l][s]*sampleCnt - prevAcc)*( band[l][s]*sampleCnt - currAcc);
						alphaDAcc += ( decodedBlockInt[b-1][l][s]*sampleCnt - prevAcc)*( decodedBlockInt[b-1][l][s]*sampleCnt - prevAcc);
						simpleAlphaNacc += ( decodedBlockInt[b-1][l][s] - prevAcc/sampleCnt)*( band[l][s] - currAcc/sampleCnt);
						simpleAlphaDacc += ( decodedBlockInt[b-1][l][s] - prevAcc/sampleCnt)*( decodedBlockInt[b-1][l][s] - prevAcc/sampleCnt);
						
						alphaN += ((double) decodedBlock[b-1][l][s] - prevMean)*((double) band[l][s] - currMean);
						alphaD += ((double) decodedBlock[b-1][l][s] - prevMean)*((double) decodedBlock[b-1][l][s] - prevMean);
					}
				}
				
				
				double alpha = alphaN/alphaD;
				long depth = 10;
				long alphaScaled = findAlpha(alphaNAcc, alphaDAcc, depth);
				long simpleAlphaScaled = findAlpha(simpleAlphaNacc, simpleAlphaDacc, depth);
				long alphaScaleVal = 512;
				long muScaled = currAcc / sampleCnt;
				//System.out.println("Current alpha and mean (int): " + ((double) alphaScaled / (double) alphaScaleVal) + ":" + ((double) simpleAlphaScaled / (double) alphaScaleVal) + "," + muScaled);
				
				
				//quantize alpha
				double alphaHat = (double) ((int) (alpha * 1024)) / 1024;
				double currMeanHat = (int) currMean;
				//System.out.println("Current alpha and mean (dbl): " + alphaHat + "," + currMeanHat);
				
				long distortionDbl = 0;
				long distortionInt = 0;
				
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						long prediction = (int) (currMeanHat + (decodedBlock[b-1][l][s] - prevMean)*alphaHat);
						long error = band[l][s] - prediction;
						//quantize error if necessary
						distortionDbl += error*error;
						decodedBlock[b][l][s] = (int) prediction + (int) error;
						
						//code mapped error
						long mappedError = error > 0 ? (2*error - 1) : (-2*error);
						//System.out.println("Coding value (dbl) (" + b + "," + l + "," + s + "): " + mappedError + " (original: " + band[l][s] + ")");
						
						//prediction for integers
						prediction = muScaled + (decodedBlockInt[b-1][l][s] - prevAcc/sampleCnt)*simpleAlphaScaled/alphaScaleVal;
						error = band[l][s] - prediction;
						decodedBlockInt[b][l][s] = prediction + error;
						distortionInt += error*error;
						mappedError = error > 0 ? (2*error - 1) : (-2*error);
						//System.out.println("Coding value (int) (" + b + "," + l + "," + s + "): " + mappedError + " (original: " + band[l][s] + ")");
					}
				}
				
				distortionDbl /= sampleCnt*sampleCnt;
				distortionInt /= sampleCnt*sampleCnt;
				
				System.out.println("Distortion was : " + distortionDbl + " " + distortionInt);
			}
		}
		
	*/
 

