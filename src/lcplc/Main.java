package lcplc;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
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

	static int[] min = new int[5];
	static int[] max = new int[5];
	
	public static void main(String[] args) {
		for (int i = 0; i < max.length; i++) {
			max[i] = Integer.MIN_VALUE;
			min[i] = Integer.MAX_VALUE;
		}
		
		
		Compressor c = new Compressor();
		c.test();
		
		for (int i = 0; i < max.length; i++) {
			System.out.println("(" + min[i] + "," + max[i] + ")");
		}
		
		/*IntegerUniformThresholdQuantizer iutq = new IntegerUniformThresholdQuantizer(1, 1);
		
		for (int i = 0; i < 0xff; i++) {
			int q = iutq.quantize(i);
			int dq = iutq.dequantize(q);
			if (dq != i) {
				System.out.println(i + "->" + dq);
			}
		}
		*/
	}
	

	public static class Compressor {
		
		private static final int CONST_ACC_QUANT = 32;
		//delta = down/up
		private static final int CONST_UTQ_UPSCALE = 2;
		private static final int CONST_UTQ_DOWNSCALE = 1;
		//set gamma to zero to avoid block skipping
		private static final int CONST_GAMMA = 0;
		
		
		public void test() {
			HyperspectralImage hi;
			try {
				hi = HyperspectralImageReader.read(input, inputHeader, true);
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				return;
			}
			
			for (Entry<HeaderConstants, Object> e: hi.getHeader().entrySet()) {
				System.out.print(e.getKey().toString() + ": " + e.getValue().toString() + "\n");
			};
			
			HyperspectralImageData hid = hi.getData();
			
			int bands = hid.getNumberOfBands();
			int lines = 16;//hid.getNumberOfLines();
			int samples = 16;//hid.getNumberOfSamples();
			
			int[][][] block = new int[bands][lines][samples];
			
			for (int b = 0; b < bands; b++) {
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						block[b][l][s] = hid.getValueAt(b, l, s);
					}
				}
			}
			
			try {
				
				System.out.println("COMPRESSING: " + 16*bands*lines*samples);

				ByteArrayOutputStream adbaos = new ByteArrayOutputStream();
				BitOutputStream bos = new BitOutputStream(adbaos);
				this.compress(block, bands, lines, samples, bos);
				
				System.out.println("COMPR:  " + bos.getBitsOutput());
				
				bos.paddingFlush();
				
				ByteArrayInputStream adbais = new ByteArrayInputStream(adbaos.toByteArray());
				BitInputStream bis = new BitInputStream(adbais);
				int[][][] uncompressedBlock = this.uncompress(bands, lines, samples, bis);
				
				System.out.println("UNCOMP: " + bis.getBitsInput());
				
				int maxDiff = 0;
				for (int b = 0; b < bands; b++) {
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							int diff = Math.abs(block[b][l][s] - uncompressedBlock[b][l][s]); 
							if (diff > maxDiff) {
								System.out.println("Diff@" + b + "," + l + "," + s + ": " + block[b][l][s] + "->" + uncompressedBlock[b][l][s]);
								maxDiff = diff;
							}
						}
					}
				}
				
				
				System.out.println("FINISHED");
			} catch (IOException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}
		}
		
		
		public void compress(int[][][] block, int bands, int lines, int samples, BitOutputStream bos) throws IOException {
			//samplers for testing in verilog/vhdl
			Sampler<Integer> alphaSampler		= new Sampler<Integer>();
			Sampler<Integer> xhatSampler 		= new Sampler<Integer>();
			Sampler<Long>    xmeanSampler		= new Sampler<Long>();
			Sampler<Long>    xhatmeanSampler	= new Sampler<Long>();
			Sampler<Integer> predictionSampler	= new Sampler<Integer>();
			
			
			
			int[][][] decodedBlock = new int[bands][lines][samples];
			
			ExpGolombCoDec expGolombZero = new ExpGolombCoDec(0);
			GolombCoDec golombCoDec = new GolombCoDec(0);
			Accumulator acc = new Accumulator(CONST_ACC_QUANT);
			IntegerUniformThresholdQuantizer iutq = new IntegerUniformThresholdQuantizer(CONST_UTQ_DOWNSCALE, CONST_UTQ_UPSCALE);
			
			//compress first band
			int[][] band = block[0];
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {
					//First sample is just coded raw since we have not initialized
					//the counters/accumulators/predictors yet
					if (l == 0 && s == 0) {
						expGolombZero.encode(block[0][l][s], bos);
						
						decodedBlock[0][l][s] = block[0][l][s];
						xhatSampler.sample(decodedBlock[0][l][s]);
						acc.add(0);
						predictionSampler.sample(0);
					//For every other sample, code following
					//the predictive scheme
					} else {
						int prediction = Predictor.basic2DPrediction(decodedBlock[0], l, s);
						predictionSampler.sample(prediction);
						
						int error = block[0][l][s] - (int) prediction;
						int qErr  = iutq.quantize(error);
						error 	  = iutq.dequantize(qErr);
						decodedBlock[0][l][s] = (int) prediction + error;
						xhatSampler.sample(decodedBlock[0][l][s]);
						
						int kj = findkj(acc);
						
						//code mapped error
						int mappedError = Mapper.mapError(qErr);
						golombCoDec.encode(kj, mappedError, bos);	//encode the error
						acc.add(Math.abs(error));		//update Rj after coding
					}
				}
			}
			
			//calculate distortion threshold
			long sampleCnt = lines*samples;
			double delta = (double) CONST_UTQ_DOWNSCALE / (double) CONST_UTQ_UPSCALE;
			double thres = (double) CONST_GAMMA * delta * delta * sampleCnt * sampleCnt / 3.0;
			System.out.println("Threshold is: " + thres);
			

			//compress rest of bands
			for (int b = 1; b < bands; b++) {
				band = block[b];
				//generate means. we'll see where these means have to be from
				long currAcc = Utils.sumArray(band, lines, samples);
				long prevAcc = Utils.sumArray(decodedBlock[b-1], lines, samples);
				xmeanSampler.sample(currAcc);
				xhatmeanSampler.sample(prevAcc);
				
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
				long alphaScaleVal = 512;
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
						long prediction = muScaled + (decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*simpleAlphaScaled/alphaScaleVal;
						predictionSampler.sample((int) prediction);
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
						if (l != 0 || s != 0) {
							savedGolombParam[l][s] = findkj(acc);
						}
						
						savedxhat[l][s] = (int) prediction + (int) error;
						
						acc.add(Math.abs(error));		//update Rj after coding
					}
				}
				
				if (distortionAcc > thres) {
					bos.writeBit(Bit.BIT_ONE);
					//code block as normal
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = savedxhat[l][s];
							xhatSampler.sample(decodedBlock[b][l][s]);
							if (l == 0 && s == 0) {
								expGolombZero.encode(savedMappedError[l][s], bos);
							} else {
								golombCoDec.encode(savedGolombParam[l][s], savedMappedError[l][s], bos);	//encode the error
							}
						}
					}
				} else {
					bos.writeBit(Bit.BIT_ZERO);
					//skip block
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = savedPrediction[l][s];
							xhatSampler.sample(decodedBlock[b][l][s]);
						}
					}
				}
				
				//System.out.println("Distortion is: " + distortionAcc + " (block was skipped: " + (distortionAcc <= thres) + ")");
			}
			
			//samplers for testing in verilog/vhdl
			alphaSampler.export(samplerBaseDir + "alpha.smpl");
			xhatSampler.export(samplerBaseDir + "xhat.smpl");
			xmeanSampler.export(samplerBaseDir + "xmean.smpl");
			xhatmeanSampler.export(samplerBaseDir + "xhatmean.smpl");
			predictionSampler.export(samplerBaseDir + "prediciton.smpl");
		}
		
		public int findAlpha(long alphaN, long alphaD, long depth) {
			//find alpha in [0, 2**depth) such that alphaD*alpha>>(depth-1) is closest to alphaN (in absolute value)
			long difference = Long.MAX_VALUE;
			int result = -1;
			int alphaRange = 1 << depth;
			for (int i = 0; i < alphaRange; i++) {
				long candidate = (alphaD*i)>>(depth-1);
				long localDiff = Math.abs(alphaN-candidate);
				if (localDiff < difference) {
					difference = localDiff;
					result = i;
				}
			}
			//System.out.println("Diff is: " + difference);
			return result;
		}
		
		
		public int findkj(Accumulator acc) {
			int Rj = (int) acc.getRunningSum();		//running count of last (at most) 32 mapped errors
			int J  =       acc.getRunningCount();	//number of samples to average out for golomb param calculation			
			int kj;									//will be the golomb parameter to code current mapped error
			for (kj = 0; (J<<kj) <= Rj; kj++);		//calculate kj
			
			return kj;
			

			
			/*int Rj = (int) acc.getRunningSum();	//running count of last (at most) 32 mapped errors
			int J  =       acc.getRunningCount();	//number of samples to average out for golomb param calculation			
			int kj = Utils.countBitsOf(J);
			kj = Rj >> kj;
			kj = Utils.countBitsOf(kj) + 1;
			return kj;*/
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
						decodedBand[l][s] = expGolombZero.decode(bis);
						acc.add(0);
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
				long alphaScaleVal = 512;
				long muScaled = bis.readBits(16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				
				//is this block skipped or not?
				boolean coded = bis.readBoolean();

				acc.reset(); 
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						long prediction = muScaled + (decodedBlock[b-1][l][s] - prevAcc/sampleCnt)*simpleAlphaScaled/alphaScaleVal;
						
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
 

