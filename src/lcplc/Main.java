package lcplc;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

import org.ejml.data.FMatrixRMaj;

import com.jypec.distortion.ImageComparisons;
import com.jypec.img.HyperspectralImage;
import com.jypec.img.HyperspectralImageData;
import com.jypec.img.HyperspectralImageIntegerData;
import com.jypec.img.ImageDataType;
import com.jypec.util.bits.Bit;
import com.jypec.util.bits.BitInputStream;
import com.jypec.util.bits.BitOutputStream;
import com.jypec.util.bits.BitStreamConstants;
import com.jypec.util.io.HyperspectralImageReader;

public class Main {

	//USE THIS SINCE ITS DATA TYPE 12: UNSIGNED TWO BYTE!!
	static String input = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.dat";
	//static String input = "C:/Users/Daniel/Hiperspectral images/Gulf_Wetlands_Sample_Rad/Suwannee_0609-1331_rad.dat";
	//static String input = "C:/Users/Daniel/Hiperspectral images/Beltsville_Radiance_w_IGM/0810_2022_rad.dat";
	static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Gulf_Wetlands_Sample_Rad/Suwannee_0609-1331_rad.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Beltsville_Radiance_w_IGM/0810_2022_rad.hdr";
	
	static String samplerBaseDir = "C:/Users/Daniel/Repositorios/Lcplc/test_data_2/";
	static String sampleExt = ".smpl";


	public static void main(String[] args) {
		/*for (int i = 0; i < 17; i++) {
			testQuantization(i, 17);
		}*/
		
		testCompressor();
		
		/*Quantizer quantizer = new ShifterQuantizer(2);
		

		int qval = quantizer.quantize(218);
		int dqval = quantizer.dequantize(qval);*/
	}
	
	
	public static void testCompressor() {
		//clear directory
		File dir = new File(samplerBaseDir);
		
		for(File file: dir.listFiles()) {
		    if (!file.isDirectory()) 
		        if (!file.delete())
		        	System.out.println("Problem deleting file: " + file.getPath());
		        else
		        	System.out.println("Deleted file: " + file.getPath());
		}
		
		/*int[] blockSizes	= {64}; //{4, 8, 16, 32};
		int[] quantizations = {0, 1, 2, 4, 8};
		double[] gammas		= {0, 0.1, 0.25, 0.5, 1, 3, 5};
		
		for (int bs: blockSizes) {
			for (int q: quantizations) {
				for (double g: gammas) {
					System.out.println("BS,Q,G: " + bs + "," + q + "," + g);
					Compressor c = new Compressor();
					c.setGamma(g);
					c.setSQDownscale(q);
					c.setBlockSize(bs, bs);
					c.test();
					System.out.println();
				}
			}
		}*/
		
		Compressor c = new Compressor();
		c.setBlockSize(16, 16);
		c.setSQDownscale(2);
		c.setGamma(3);
		c.test();
		System.out.println();
	}
	
	
	public static void testQuantization(int downscale, int depth) {
		System.out.println("Testing quantization for dq: " + downscale);
		
		Quantizer quantizer = new ShifterQuantizer(downscale);
		
		for (int i = -(1 << depth); i < (1 << depth); i++) {
			//option 1
			int qval = quantizer.quantize(i);
			int dqval = quantizer.dequantize(qval);
			
			//option 2, just remove bytes
			int candidate = i >= 0 ? i : i;
			int rawqdq = (candidate + ((1 << downscale) >> 1)) & ((-1) << downscale);
			rawqdq = i > 0 ? rawqdq: rawqdq;
			
			if (dqval != rawqdq) {
				System.out.println("Fails @ " + i + "(" + dqval + "," + rawqdq + ")");
			}
			
			//System.out.println(i + "-> (" + dqval + "," + rawqdq + ")");
		}
	}
	

	public static class Compressor {
		
		///////Constants
		private static final boolean FAST_COMPRESS = false;
		private static final boolean REPORT_BLOCK_STATUS = true;
		private static final boolean USE_PRECALCULATED_MEAN = true;
		private static final boolean COMPARE = true;
		private static final int CONST_ACC_QUANT = 32;
		private static final int BLOCKS_TO_CODE = 2; //Integer.MAX_VALUE; //code the full image
		private static final int BLOCKS_TO_SKIP = 0;
		///////
		
		//variables
		private int SQ_DOWNSCALE = 0;
		private double GAMMA = 0;
		private int MAX_LINES_PER_BLOCK = 32;
		private int MAX_SAMPLES_PER_BLOCK = 32;
		
		//set by image data
		private int SAMPLE_DEPTH = 16;
		
		public Compressor() {
			//set default compression parameters
			this.setBlockSize(16, 16);
			this.setSQDownscale(0);
			this.setGamma(0);
		}
		
		public void setBlockSize(int lines, int samples) {
			this.MAX_LINES_PER_BLOCK = lines;
			this.MAX_SAMPLES_PER_BLOCK = samples;
		}
		
		public void setSQDownscale(int SQDownscale) {
			this.SQ_DOWNSCALE = SQDownscale;
		}
		
		public void setGamma(double gamma) {
			this.GAMMA = gamma;
		}
		
		
		
		
		
		
		
		public void test() {
			HyperspectralImage hi;
			try {
				hi = HyperspectralImageReader.read(input, inputHeader, true);
				/*for (Entry<HeaderConstants, Object> e: hi.getHeader().entrySet()) {
					System.out.print(e.getKey().toString() + ": " + e.getValue().toString() + "\n");
				};*/
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				return;
			}
			
			HyperspectralImageData hid = hi.getData();
			
			int imgBands	= hid.getNumberOfBands();
			int imgLines	= hid.getNumberOfLines();
			int imgSamples	= hid.getNumberOfSamples();
			this.SAMPLE_DEPTH = hid.getDataType().getBitDepth();
			
			ByteArrayOutputStream adbaos = new ByteArrayOutputStream();
			BitOutputStream bos = new BitOutputStream(adbaos);
			
			ByteArrayOutputStream rawBinBaos = new ByteArrayOutputStream();
			BitOutputStream rawBinIn = new BitOutputStream(rawBinBaos);
			
			///////
			//get starting time here
			long sTime = System.nanoTime();
			///////
			
			int compressedBlocks = 0;
			int skippedBlocks = 0;
			for (int l = 0; l < imgLines; l += MAX_LINES_PER_BLOCK) {
				for (int s = 0; s < imgSamples; s += MAX_SAMPLES_PER_BLOCK) {
					if (skippedBlocks < BLOCKS_TO_SKIP) {
						skippedBlocks++;
						compressedBlocks++;
						continue;
					}
					int blockBands = imgBands;
					int blockLines = Math.min(MAX_LINES_PER_BLOCK, imgLines - l);
					int blockSamples = Math.min(MAX_SAMPLES_PER_BLOCK, imgSamples - s);
					
					//fill block up
					int[][][] block = new int[blockBands][blockLines][blockSamples];
					for (int bb = 0; bb < blockBands; bb++) {
						for (int ll = 0; ll < blockLines; ll++) {
							for (int ss = 0; ss < blockSamples; ss++) {
								block[bb][ll][ss] = hid.getValueAt(bb, ll+l, ss+s);
								if (!FAST_COMPRESS) { 
									try {
										rawBinIn.writeBits(hid.getValueAt(bb, ll+l, ss+s), 16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
									} catch (IOException e) {e.printStackTrace();}
								}
							}
						}
					}
					//compress block
					try {
						this.compress(block, blockBands, blockLines, blockSamples, compressedBlocks == BLOCKS_TO_CODE - 1,  bos);
					} catch (IOException e) {
						e.printStackTrace();
						System.exit(0);
					}
					if (REPORT_BLOCK_STATUS)
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
			
			///////
			//get ending time here
			long eTime = System.nanoTime();
			long time = eTime - sTime;
			double secondTime = ((double) time) / 1000000000.0;
			System.out.println("Ctime: " + secondTime);
			System.out.println("From: " + hid.getBitSize() + " downto " + bos.getBitsOutput());
			double rate = (double) bos.getBitsOutput() / (double) hid.getBitSize();
			System.out.println("Rate: " + rate);
			sTime = System.nanoTime();
			///////
			
			
			ByteArrayInputStream adbais = new ByteArrayInputStream(adbaos.toByteArray());
			BitInputStream bis = new BitInputStream(adbais);
			int[][][] result = new int[imgBands][imgLines][imgSamples];
			
			int unCompressedBlocks = 0;
			skippedBlocks = 0;
			for (int l = 0; l < imgLines; l += MAX_LINES_PER_BLOCK) {
				for (int s = 0; s < imgSamples; s += MAX_SAMPLES_PER_BLOCK) {
					if (skippedBlocks < BLOCKS_TO_SKIP) {
						unCompressedBlocks++;
						skippedBlocks++;
						continue;
					}
					int blockBands = imgBands;
					int blockLines = Math.min(MAX_LINES_PER_BLOCK, imgLines - l);
					int blockSamples = Math.min(MAX_SAMPLES_PER_BLOCK, imgSamples - s);
					
					//uncompress block
					try {
						int[][][] partialResult = this.uncompress(blockBands, blockLines, blockSamples, bis);
						for (int i = 0; i < blockBands; i++) {
							for (int j = 0; j < blockLines; j++) {
								for (int k = 0; k < blockSamples; k++) {
									result[i][j+l][k+s] = partialResult[i][j][k]; 
								}
							}
						}
					} catch (IOException e) {
						e.printStackTrace();
						System.exit(0);
					}
					if (REPORT_BLOCK_STATUS)
						System.out.println("UNCOMPR:  " + bis.getBitsInput());
					unCompressedBlocks++;
					if (unCompressedBlocks >= BLOCKS_TO_CODE)
						break;
				}
				if (unCompressedBlocks >= BLOCKS_TO_CODE)
					break;
			}
			
			///////
			//get ending time here
			eTime = System.nanoTime();
			time = eTime - sTime;
			secondTime = ((double) time) / 1000000000.0;
			System.out.print("Total uncompress time is: " + secondTime + "\n");
			///////
			
			
			//output bytes
			if (!FAST_COMPRESS) {
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
				
				//output raw input and raw output (in read raster order)
				try {
					rawBinIn.flush();
					byte[] rbb = rawBinBaos.toByteArray();
					//change endianness
					changeEndianness(rbb, 1, 0, 3, 2);
					FileOutputStream stream = new FileOutputStream(samplerBaseDir + "rawIn.bin");
					stream.write(rbb);
					stream.close();
					
					changeEndianness(bytesoutput, 3, 2, 1, 0);
					stream = new FileOutputStream(samplerBaseDir + "rawOut.bin");
					stream.write(bytesoutput);
					stream.close();
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
			}
			
			//compare
			if (COMPARE) {
				//get both matrices
				FMatrixRMaj fdm = hid.tofloatMatrix();
				ImageDataType idt = hid.getDataType();
				hid = null;
				
				HyperspectralImageData hidr = new HyperspectralImageIntegerData(idt, imgBands, imgLines, imgSamples);
				for (int i = 0; i < imgBands; i++) {
					for (int j = 0; j < imgLines; j++) {
						for (int k = 0; k < imgSamples; k++) {
							hidr.setValueAt(result[i][j][k], i, j, k);
						}
					}
				}
				FMatrixRMaj sdm = hidr.tofloatMatrix();
				float dynRange = hidr.getDataType().getDynamicRange();
				
				//garbage collect if necessary
				
				hidr = null;
				
				//output metrics
				System.out.println("PSNR: " + ImageComparisons.rawPSNR(fdm, sdm, dynRange));
				//System.out.println("Normalized PSNR is: " + ImageComparisons.normalizedPSNR(fdm, sdm));
				//System.out.println("powerSNR is: " + ImageComparisons.powerSNR(fdm, sdm));
				System.out.println("SNR: " + ImageComparisons.SNR(fdm, sdm));
				System.out.println("MSE: " + ImageComparisons.MSE(fdm, sdm));
				//System.out.println("maxSE is: " + ImageComparisons.maxSE(fdm, sdm));
				//System.out.println("MSR is: " + ImageComparisons.MSR(fdm, sdm));
				//System.out.println("SSIM is: " + ImageComparisons.SSIM(fdm, sdm, dynRange));
			}
			
			
			try {
				bos.close();
				rawBinIn.close();
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
		
		
		public int qdq(int q, int ds) {
			return (q + ((1 << ds) >> 1)) & ((-1) << ds);
		}
		
		public void compress(int[][][] block, int bands, int lines, int samples, boolean flushBlock, BitOutputStream bos) throws IOException {
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
			Sampler<Integer> xSampler_last_r	= new Sampler<Integer>("x_last_r");
			Sampler<Integer> xSampler_last_s	= new Sampler<Integer>("x_last_s");
			Sampler<Integer> xSampler_last_b	= new Sampler<Integer>("x_last_b");
			Sampler<Integer> xSampler_last_i	= new Sampler<Integer>("x_last_i");
			
			Sampler<Integer> xtildeSampler		= new Sampler<Integer>("xtilde");
			Sampler<Integer> xtilde_last_s      = new Sampler<Integer>("xtilde_last_s");
			
			Sampler<Integer> quantSampler		= new Sampler<Integer>("quant");
			Sampler<Integer> dequantSampler		= new Sampler<Integer>("unquant");
			
			Sampler<Integer> mappedErrorSampler = new Sampler<Integer>("merr");
			Sampler<Integer> kjSampler			= new Sampler<Integer>("kj");
			
			Sampler<Integer> xhatrawSampler 	= new Sampler<Integer>("xhatraw");
			Sampler<Integer> xhatraw_last_s		= new Sampler<Integer>("xhatraw_last_s");
			Sampler<Integer> xhatraw_last_b		= new Sampler<Integer>("xhatraw_last_b");
			
			Sampler<Integer> dFlagSampler		= new Sampler<Integer>("dflag");
			
			Sampler<Integer> errorSampler		= new Sampler<Integer>("error");
			
	
			
			
			int[][][] decodedBlock = new int[bands][lines][samples];
			
			ExpGolombCoDec expGolombZero = new ExpGolombCoDec(0);
			GolombCoDec golombCoDec = new GolombCoDec(0);
			Accumulator acc = new Accumulator(CONST_ACC_QUANT);
			Quantizer quantizer = new ShifterQuantizer(SQ_DOWNSCALE);
			
			long sampleCnt = lines*samples;
			
			if (!FAST_COMPRESS) {
				expGolombZero.startSampling("egz_input", "egz_code", "egz_quant");
				golombCoDec.startSampling("gc_input", "gc_param", "gc_code", "gc_quant");
			}
			
			//write header for first band
			int fbacc = 0;
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {	
					fbacc += block[0][l][s];
				}
			}
			long lastbandAcc = fbacc;
			//bos.writeBit(Bit.fromBoolean(true));
			//bos.writeBits((int) 0, 10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
			bos.writeBits((int) (lastbandAcc / sampleCnt), 16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
			/////////////////////////////
			
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
					int quant, dequant;
					
					if (l == 0 && s == 0) {
						quant = quantizer.quantize(block[0][l][s]);
						dequant = quantizer.dequantize(quant); 
						
						mappedError = Mapper.mapError(quant); //Mapper.mapError(block[0][l][s]);
						
						
						expGolombZero.encode(mappedError, bos);
						//mimic hw by injecting here the first sample
						 
						prediction = 0;
						
						decodedBlock[0][l][s] = dequant;
						acc.add(Math.abs(dequant));
						
					//For every other sample, code following
					//the predictive scheme
					} else {
						prediction = Predictor.basic2DPrediction(decodedBlock[0], l, s);
						
						
						error = block[0][l][s] - (int) prediction;
						quant  = quantizer.quantize(error);
						dequant= quantizer.dequantize(quant);
						
						decodedBlock[0][l][s] = (int) prediction + dequant;

						kj = findkj(acc);
						
						//code mapped error
						mappedError = Mapper.mapError(quant);
						golombCoDec.encode(kj, mappedError, bos);	//encode the error
						acc.add(Math.abs(dequant));		//update Rj after coding
					}
					
					if (!FAST_COMPRESS) {
						xFirstBand.sample(block[0][l][s]);
						xTildeFirstBand.sample(prediction);
						xFirstBand_last_r.sample(s == samples-1 ? 1 : 0);
						xFirstBand_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						
						xSampler.sample(block[0][l][s]);
						xSampler_last_r.sample(s == samples-1 ? 1 : 0);
						xSampler_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						xSampler_last_b.sample(s == samples-1 && l == lines-1 && 0 == bands-1 ? 1 : 0);
						xSampler_last_i.sample(s == samples-1 && l == lines-1 && 0 == bands-1 && flushBlock ? 1 : 0);
						
						xtildeSampler.sample(prediction);
						xtilde_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						
						quantSampler.sample(quant);
						dequantSampler.sample(dequant);
						mappedErrorSampler.sample(mappedError);
						if (s != samples-1 || l != lines-1) kjSampler.sample(findkj(acc));
						
						xhatrawSampler.sample(decodedBlock[0][l][s]);
						xhatraw_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						xhatraw_last_b.sample(s == samples-1 && l == lines-1 && 0 == bands-1 ? 1 : 0);
						
						
						errorSampler.sample(error);
					}
				}
			}
			
			//calculate distortion threshold
			double delta = (double) (1 << this.SQ_DOWNSCALE);
			double thres = GAMMA * delta * delta * (double) sampleCnt * (double) sampleCnt / 3.0;
			if (REPORT_BLOCK_STATUS)
				System.out.println("THRESH: " + thres);
			
			if (!FAST_COMPRESS)
				dFlagSampler.sample(1); //first sample should be 1 to save xhatraw samples instead of empty values
			
			//compress rest of bands
			for (int b = 1; b < bands; b++) {
				band = block[b];
				//generate means. we'll see where these means have to be from
				long currAcc = Utils.sumArray(band, lines, samples);
				long prevAcc;
				if (USE_PRECALCULATED_MEAN)
					prevAcc = lastbandAcc;
				else
					prevAcc = Utils.sumArray(decodedBlock[b-1], lines, samples);
				
				//sample the decoded block
				if (!FAST_COMPRESS) {
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							xOtherBands.sample(block[b][l][s]);
							xhatSampler.sample(decodedBlock[b-1][l][s]);
							xhat_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
						}
					}
					xmeanSampler.sample(currAcc/sampleCnt);
					xhatmeanSampler.sample(prevAcc/sampleCnt);
				}
				
				//generate alpha value. Could try to generate it using the original band as well to see performance
				long simpleAlphaNacc = 0;
				long simpleAlphaDacc = 0;
				for (int l = 0; l < lines; l++) {
					for (int s = 0; s < samples; s++) {
						int dBSample = decodedBlock[b-1][l][s];
						int cBSample = band[l][s];
						long dBSub = (dBSample - prevAcc/sampleCnt);
						long cBSub = (cBSample - currAcc/sampleCnt);
						long simpleAlphaNaccAdd = dBSub*cBSub;
						long simpleAlphaDaccAdd = dBSub*dBSub;
						simpleAlphaNacc += simpleAlphaNaccAdd;
						simpleAlphaDacc += simpleAlphaDaccAdd;
					}
				}
				
				//allocate 10 bits for alpha (when using it we need to divide by 512
				//to stay in the [0, 2) range
				int simpleAlphaScaled = findAlpha(simpleAlphaNacc, simpleAlphaDacc, 10);
				if (!FAST_COMPRESS)
					alphaSampler.sample(simpleAlphaScaled);
				long alphaScaleVal = 9; //512;
				//mu is 16 bits wide, and should stay that way since we are averaging 16-bit values
				long muScaled = currAcc / sampleCnt;

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
						int quant  = quantizer.quantize((int) error);
						int dequant = quantizer.dequantize(quant); 
						long mappedError = Mapper.mapError(quant);
						savedMappedError[l][s] = (int) mappedError;
						
						savedxhat[l][s] = (int) prediction + (int) dequant;
						
						if (l != 0 || s != 0) {
							savedGolombParam[l][s] = findkj(acc);
						}
						acc.add(Math.abs(dequant));		//update Rj after coding
						
						if (!FAST_COMPRESS) {
							xTildeOtherBands.sample((int) prediction);
							xTilde_o_last_s.sample(l == lines-1 && s == samples-1 ? 1 : 0);
							
							xSampler.sample(block[b][l][s]);
							xSampler_last_r.sample(s == samples-1 ? 1 : 0);
							xSampler_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
							xSampler_last_b.sample(s == samples-1 && l == lines-1 && b == bands-1 ? 1 : 0);
							xSampler_last_i.sample(s == samples-1 && l == lines-1 && b == bands-1 && flushBlock ? 1 : 0);
							
							xtildeSampler.sample((int) prediction);
							xtilde_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
							
							quantSampler.sample(quant);
							dequantSampler.sample(dequant);
							
							mappedErrorSampler.sample((int)mappedError);
							if (s != samples-1 || l != lines-1) kjSampler.sample(findkj(acc));
							
							xhatrawSampler.sample(savedxhat[l][s]);
							xhatraw_last_s.sample(s == samples-1 && l == lines-1 ? 1 : 0);
							xhatraw_last_b.sample(s == samples-1 && l == lines-1 && b == bands-1 ? 1 : 0);
							
							errorSampler.sample(error);
						}
					}
				}
				
				//write flag and alpha and mu
				bos.writeBit(Bit.fromBoolean(distortionAcc > thres));
				bos.writeBits((int) simpleAlphaScaled, 10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				bos.writeBits((int) muScaled, 16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				
				if (distortionAcc > thres) {
					if (!FAST_COMPRESS)
						dFlagSampler.sample(1);
					//code block as normal
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = Utils.clamp(savedxhat[l][s], 0, (1 << SAMPLE_DEPTH) - 1);
							if (l == 0 && s == 0) {
								expGolombZero.encode(savedMappedError[l][s], bos);
							} else {
								golombCoDec.encode(savedGolombParam[l][s], savedMappedError[l][s], bos);	//encode the error
							}
						}
					}
				} else {
					if (!FAST_COMPRESS)
						dFlagSampler.sample(0);
					//skip block
					for (int l = 0; l < lines; l++) {
						for (int s = 0; s < samples; s++) {
							decodedBlock[b][l][s] = Utils.clamp(savedPrediction[l][s], 0, (1 << SAMPLE_DEPTH) - 1);
						}
					}
				}
				
				lastbandAcc = currAcc;
				//System.out.println("Distortion is: " + distortionAcc + " (block was skipped: " + (distortionAcc <= thres) + ")");
			}
			
			//samplers for testing in verilog/vhdl
			if (!FAST_COMPRESS) {
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
				xSampler_last_r.export();
				xSampler_last_s.export();
				xSampler_last_b.export();
				xSampler_last_i.export();
				
				xtildeSampler.export();
				xtilde_last_s.export();
				
				quantSampler.export();
				dequantSampler.export();
				
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

			return result;
		}
		
		
		public int findkj(Accumulator acc) {
			int Rj = (int) acc.getRunningSum();	//running count of last (at most) 32 mapped errors
			int J  =       acc.getRunningCount();	//number of samples to average out for golomb param calculation			
			int kj = Utils.countBitsOf(J);
			kj = Rj >> kj;
			kj = Utils.countBitsOf(kj) + 1;
			return kj;
		}
		
		
		public void changeEndianness(byte[] arr, int s0, int s1, int s2, int s3) {
			//change endianness
			for (int i = 0; i+3 < arr.length; i += 4) {
				byte[] tmp = new byte[4];
				tmp[0] = arr[i];
				tmp[1] = arr[i+1];
				tmp[2] = arr[i+2];
				tmp[3] = arr[i+3];
				// swap
				arr[i] 	 = tmp[s0];
				arr[i+1] = tmp[s1];
				arr[i+2] = tmp[s2];
				arr[i+3] = tmp[s3];
			}
		}
		
		
		
		public int[][][] uncompress(int bands, int lines, int samples, BitInputStream bis) throws IOException {
			int[][][] decodedBlock = new int[bands][lines][samples];
			
			ExpGolombCoDec expGolombZero = new ExpGolombCoDec(0);
			GolombCoDec golombCoDec = new GolombCoDec(0);
			Accumulator acc = new Accumulator(CONST_ACC_QUANT);
			Quantizer quantizer = new ShifterQuantizer(SQ_DOWNSCALE);
			
			long sampleCnt = lines*samples;
			
			//bis.readBit();
			//bis.readBits(10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
			long lastbandAcc = bis.readBits(16, BitStreamConstants.ORDERING_LEFTMOST_FIRST)*sampleCnt;
			/////////////////////////////
			
			//decompress first band
			int[][] decodedBand = decodedBlock[0];
			for (int l = 0; l < lines; l++) {
				for (int s = 0; s < samples; s++) {
					if (l == 0 && s == 0) {
						/*decodedBand[l][s] = expGolombZero.decode(bis);
						acc.add(0);*/
						int mappedErr = expGolombZero.decode(bis);
						int quant = Mapper.unmapError(mappedErr);
						int dequant = quantizer.dequantize(quant);
						decodedBlock[0][l][s] = dequant;
						acc.add(dequant);
					} else {
						int prediction = Predictor.basic2DPrediction(decodedBand, l, s);
						
						//decode mapped error
						int kj = findkj(acc);
						
						int mappedError = golombCoDec.decode(kj, bis);
						int qErr = Mapper.unmapError(mappedError);
						int error = quantizer.dequantize(qErr);
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
				if (USE_PRECALCULATED_MEAN)
					prevAcc = lastbandAcc;

				//is this block skipped or not?
				boolean coded = bis.readBoolean();
				
				//generate alpha value. Could try to generate it using the original band as well to see performance
				long simpleAlphaScaled = bis.readBits(10, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				long alphaScaleVal = 9; //512;
				long muScaled = bis.readBits(16, BitStreamConstants.ORDERING_LEFTMOST_FIRST);
				lastbandAcc = muScaled*sampleCnt;

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
							int error = quantizer.dequantize(qErr);
							
							decodedBlock[b][l][s] = Utils.clamp((int) prediction + error, 0, (1 << SAMPLE_DEPTH) - 1);
							acc.add(Math.abs(error));		//update Rj after coding
						} else {
							decodedBlock[b][l][s] = Utils.clamp((int) prediction, 0, (1 << SAMPLE_DEPTH) - 1);
						}
					}
				}
			}
			
			return decodedBlock;
		}
	}	
}