package lcplc.cli;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.ParseException;


/**
 * Store input arguments in their parsed form for easier processing
 * @author Daniel
 */
public class InputArguments {
	/** Help was requested */
	public boolean help = false;
	/** Asked to compress */
	public boolean compress = false;
	/** Asked to decompress */
	public boolean decompress = false;
	
	
	//files
	/** Input file path. Null if not set */
	public String input = null;
	/** Input file header. Null if not set */
	public String inputHeader = null;
	/** Output file path. Null if not set */
	public String output = null;
	/** Output file header. Null if not set */
	public String outputHeader = null;
	
	//image size
	/** use custom image size */
	public boolean useCustomSize = false;
	/** number of bands in custom size */
	public int bands = 0;
	/** number of lines in custom size */
	public int lines = 0;
	/** number of samples in custom size */
	public int samples = 0;
	
	//Compression parameters
	/** use custom block size when compressing */
	public boolean useCustomBlockSize = false;
	public int blockLines = 0;
	public int blockSamples = 0;
	/** use custom downscale */
	public boolean useCustomDownscale = false;
	public int sqDownscale = 0;
	/** use custom gamma */
	public boolean useCustomGamma = false;
	public double gamma = 0;
	/** type for decompressing */
	public int typeDepth = 16;
	public boolean typeSigned = false;
	
	
	
	
	/**
	 * @param line line where to parse the commands from
	 * @return an InputArguments object filled from the command line
	 * @throws ParseException 
	 */
	public static InputArguments parseFrom(CommandLine line) throws ParseException {
		InputArguments args = new InputArguments();

		args.help = line.hasOption(LCPLCCLI.OPTION_HELP);
		
		args.compress = line.hasOption(LCPLCCLI.OPTION_COMPRESS);
		args.decompress = line.hasOption(LCPLCCLI.OPTION_DECOMPRESS);
		
		args.input = line.getOptionValue(LCPLCCLI.OPTION_INPUT);
		args.output = line.getOptionValue(LCPLCCLI.OPTION_OUTPUT);
		args.inputHeader = line.getOptionValue(LCPLCCLI.OPTION_INPUT_HEADER);
		args.outputHeader = line.getOptionValue(LCPLCCLI.OPTION_OUTPUT_HEADER);
		
		String[] sizeArgs = line.getOptionValues(LCPLCCLI.OPTION_CUSTOM_SIZE);
		if (sizeArgs != null) {
			args.useCustomSize = true;
			args.bands   = Integer.parseInt(sizeArgs[0]);
			args.lines   = Integer.parseInt(sizeArgs[1]);
			args.samples = Integer.parseInt(sizeArgs[2]);
		} else {
			args.useCustomSize = false;
		}
		
		sizeArgs = line.getOptionValues(LCPLCCLI.OPTION_CUSTOM_BLOCK_SIZE);
		if (sizeArgs != null) {
			args.useCustomBlockSize = true;
			args.blockLines   = Integer.parseInt(sizeArgs[0]);
			args.blockSamples   = Integer.parseInt(sizeArgs[1]);
		} else {
			args.useCustomBlockSize = false;
		}

		args.useCustomDownscale = line.hasOption(LCPLCCLI.OPTION_CUSTOM_DOWNSCALE);
		if (args.useCustomDownscale)
			args.sqDownscale = Integer.parseInt(line.getOptionValue(LCPLCCLI.OPTION_CUSTOM_DOWNSCALE));
		
		args.useCustomGamma = line.hasOption(LCPLCCLI.OPTION_CUSTOM_GAMMA);
		if (args.useCustomGamma)
			args.gamma = Double.parseDouble(line.getOptionValue(LCPLCCLI.OPTION_CUSTOM_GAMMA));
		
		if (args.decompress) {
			if (!line.hasOption(LCPLCCLI.OPTION_TYPE_DEPTH)) 
				throw new ParseException("Decompression needs type bitdepth and sign");
			else
				args.typeDepth = Integer.parseInt(line.getOptionValue(LCPLCCLI.OPTION_TYPE_DEPTH));
		}
		
		args.typeSigned = line.hasOption(LCPLCCLI.OPTION_TYPE_SIGNED);
		
		return args;
	}
}
