package lcplc.cli;

import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;

/**
 * Anything related to command line interface stuff goes here
 * @author Daniel
 */
public class LCPLCCLI {
	/** Help option constant. Use for retrieving arguments and/or flags */
	public static final String OPTION_HELP = "help";
	/** Compress/Decompress/Compare */
	public static final String OPTION_COMPRESS = "compress";
	public static final String OPTION_DECOMPRESS = "decompress";
	public static final String OPTION_CUSTOM_SIZE = "custom_size";
	/** Input/Output file options */
	public static final String OPTION_INPUT = "input";
	public static final String OPTION_INPUT_HEADER = "input_header";
	public static final String OPTION_OUTPUT = "output";
	public static final String OPTION_OUTPUT_HEADER = "output_header";
	/** Algorithm options */
	public static final String OPTION_CUSTOM_BLOCK_SIZE = "block_size";
	public static final String OPTION_CUSTOM_DOWNSCALE = "downscale";
	public static final String OPTION_CUSTOM_GAMMA = "gamma";
	/** Decompress type options */
	public static final String OPTION_TYPE_DEPTH = "type_depth";
	public static final String OPTION_TYPE_SIGNED = "type_signed";
	
	
	/* Options for jypec */
	private static Options lcplcOptions;
	/* Only one instance */
	static {
		/* flags */
		Option help				= new Option("h", OPTION_HELP, false, "print this message");
		Option compress			= new Option("c", OPTION_COMPRESS, false, "compress image");
		Option decompress		= new Option("d", OPTION_DECOMPRESS, false, "decompress image");
		
		/* input output files */
		Option input = Option
				.builder("i")
				.argName("file")
				.desc("input file")
				.hasArg()
				.longOpt(OPTION_INPUT)
				.required()
				.build();
		
		Option inputHeader = Option
				.builder()
				.argName("file")
				.desc("input file header location")
				.hasArg()
				.longOpt(OPTION_INPUT_HEADER)
				.build();
		
		Option output = Option
				.builder("o")
				.argName("file")
				.desc("output file")
				.hasArg()
				.longOpt(OPTION_OUTPUT)
				.required()
				.build();
		
		Option outputHeader = Option
				.builder()
				.argName("file")
				.desc("output file header location")
				.hasArg()
				.longOpt(OPTION_OUTPUT_HEADER)
				.build();
		
		Option blockSize = Option
				.builder()
				.argName("lines samples")
				.desc("Compression block dimensions")
				.numberOfArgs(2)
				.longOpt(OPTION_CUSTOM_BLOCK_SIZE)
				.build();
		
		Option downscale = Option
				.builder()
				.argName("bits")
				.desc("Downscale by that amount")
				.hasArg()
				.longOpt(OPTION_CUSTOM_DOWNSCALE)
				.build();
		
		Option gamma = Option
				.builder()
				.argName("gamma")
				.desc("Gamma value that sets the threshold for block skipping")
				.hasArg()
				.longOpt(OPTION_CUSTOM_GAMMA)
				.build();
		
		Option customSize = Option
				.builder()
				.argName("dimensions")
				.desc("custom number of bands, lines, samples")
				.numberOfArgs(3)
				.longOpt(OPTION_CUSTOM_SIZE)
				.build();

		Option typeDepth = Option
				.builder()
				.argName("bits")
				.desc("bit depth of input stream")
				.hasArg()
				.longOpt(OPTION_TYPE_DEPTH)
				.build();
		
		Option typeSigned = Option
				.builder()
				.desc("set if the type is signed")
				.longOpt("signed data type or not")
				.build();
		
		lcplcOptions = new Options();
		
		lcplcOptions.addOption(output);
		lcplcOptions.addOption(input);
		lcplcOptions.addOption(help);
		lcplcOptions.addOption(inputHeader);
		lcplcOptions.addOption(outputHeader);
		lcplcOptions.addOption(compress);
		lcplcOptions.addOption(decompress);
		lcplcOptions.addOption(blockSize);
		lcplcOptions.addOption(downscale);
		lcplcOptions.addOption(gamma);
		lcplcOptions.addOption(customSize);
		lcplcOptions.addOption(typeDepth);
		lcplcOptions.addOption(typeSigned);
	}
	
	
	/**
	 * testing
	 * @return the options for the jypec cli
	 */
	public static Options getOptions() {
		return lcplcOptions;
	}

	/**
	 * Prints the help for the command line interface of jypec
	 */
	public static void printHelp() {
		HelpFormatter formatter = new HelpFormatter();
		formatter.printHelp( "lcplc", LCPLCCLI.getOptions());
	}

}
