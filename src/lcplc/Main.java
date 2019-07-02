package lcplc;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.ParseException;

import com.jypec.img.HyperspectralImage;
import com.jypec.img.HyperspectralImageData;
import com.jypec.img.ImageDataType;
import com.jypec.util.bits.BitInputStream;
import com.jypec.util.bits.BitOutputStream;
import com.jypec.util.io.HyperspectralImageReader;

import lcplc.cli.InputArguments;
import lcplc.cli.LCPLCCLI;
import lcplc.core.Compressor;
import lcplc.util.Sampler;

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


	/**
	 * @param args
	 */
	public static void main(String[] args) {
		//Debug stuff
		Sampler.setSamplePath(samplerBaseDir);
		Sampler.setSampleExt(sampleExt);
		
	    //create the parser
	    CommandLineParser parser = new DefaultParser();
	    try {
	        //parse the command line arguments
	        CommandLine line = parser.parse( LCPLCCLI.getOptions(), args );
	        InputArguments iArgs = InputArguments.parseFrom(line);
	        //go through options
	        if (iArgs.help) {
	        	printHelp();
	        } else if (iArgs.compress) {
	        	try {
	        		//read input image
	        		HyperspectralImage hi = HyperspectralImageReader.read(iArgs.input, iArgs.inputHeader, true);	   
	        		HyperspectralImageData hid = hi.getData();
	        		if (iArgs.useCustomSize)
	        			hid = hid.resize(iArgs.bands, iArgs.lines, iArgs.samples);
	        		
	        		//call compress function
	        		Compressor c = new Compressor();
	        		if (iArgs.useCustomBlockSize)
	        			c.setBlockSize(iArgs.blockLines, iArgs.blockSamples);
	        		if (iArgs.useCustomDownscale)
	        			c.setSQDownscale(iArgs.sqDownscale);
	        		if (iArgs.useCustomGamma) 
	        			c.setGamma(iArgs.gamma);
	        		
	        		//TODO call compress function
	        		BitOutputStream bos = new BitOutputStream(new FileOutputStream(new File(iArgs.output)));
	        		c.compress(hid, bos);
	        		
	        		System.out.println();

				} catch (IOException e) {
					e.printStackTrace();
				}
	        } else if (line.hasOption(LCPLCCLI.OPTION_DECOMPRESS)) {
	        	try {
					//do stuff and call decompress function
	        		Compressor c = new Compressor();
	        		if (iArgs.useCustomBlockSize)
	        			c.setBlockSize(iArgs.blockLines, iArgs.blockSamples);
	        		if (iArgs.useCustomDownscale)
	        			c.setSQDownscale(iArgs.sqDownscale);
	        		if (iArgs.useCustomGamma) 
	        			c.setGamma(iArgs.gamma);
	        		
	        		BitInputStream bis = new BitInputStream(new FileInputStream(new File(iArgs.input)));
	        		ImageDataType idt = new ImageDataType(iArgs.typeDepth, iArgs.typeSigned);
	        		HyperspectralImageData hid = c.uncompress(idt, iArgs.bands, iArgs.lines, iArgs.samples, bis);
				} catch (IOException e) {
					e.printStackTrace();
				}
	        } else {
	        	throw new ParseException("Missing options -c -d, i don't know what to do");
	        }
	    }
	    catch( ParseException exp ) {
	        System.err.println( "Parsing failed.  Reason: " + exp.getMessage() );
	        printHelp();
	    }
	}
	
	
	/**
	 * Prints help for the command line interface
	 */
	private static void printHelp() {
		LCPLCCLI.printHelp();
	}
	
}