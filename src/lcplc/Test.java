package lcplc;

public class Test {
	
	static String input = "C:/Users/Daniel/Hiperspectral images/cupriteBSQ/Cuprite";
	//static String input= "C:/Users/Daniel/Hiperspectral images/CCSDS 123 suite/AVIRIS/aviris_hawaii_f011020t01p03r05_sc01.uncal-u16be-224x512x614.raw";
	//static String input = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.dat";
	//static String input = "C:/Users/Daniel/Hiperspectral images/Gulf_Wetlands_Sample_Rad/Suwannee_0609-1331_rad.dat";
	//static String input = "C:/Users/Daniel/Hiperspectral images/Beltsville_Radiance_w_IGM/0810_2022_rad.dat";
	static String inputHeader = "C:/Users/Daniel/Hiperspectral images/cupriteBSQ/Cuprite.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/CCSDS 123 suite/AVIRIS/aviris_hawaii_f011020t01p03r05_sc01.uncal-u16be-224x512x614.raw.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Reno_Radiance_wIGMGLT/0913-1248_rad.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Gulf_Wetlands_Sample_Rad/Suwannee_0609-1331_rad.hdr";
	//static String inputHeader = "C:/Users/Daniel/Hiperspectral images/Beltsville_Radiance_w_IGM/0810_2022_rad.hdr";
	
	
	static String output = "C:/Users/Daniel/Basurero/output.dat";
	static String output2 = "C:/Users/Daniel/Basurero/output2.dat";
	
	
	static String[] argsCompression = 
		{
			//"--downscale", "2",
			//"--gamma", "3",
			"--block_size", "32", "32",
			"-i", input,
			"--input_header", inputHeader,
			"-o", output,
			"-c",
			"--custom_size", "360", "32", "32"
		};
	
	static String[] argsDecompression = 
		{
			//"--downscale", "2",
			//"--gamma", "3",
			"--block_size", "32", "32",
			"-i", output,
			"-o", output2,
			"-d",
			"--type_depth", "16",
			"--custom_size", "360", "32", "32",			
		};

	static String[] argsComparison = 
		{
			"--downscale", "2",
			"--gamma", "3",
			"--block_size", "32", "32",
			"-i", input,
			"--input_header", inputHeader,
			"-o", output,
			"-k",
			//"--custom_size", "360", "32", "32"	
		};
	
	public static void main(String[] args) {
		//Test.multiTest();
		//Main.main(argsComparison);
		Main.main(argsCompression);
		//Main.main(argsDecompression);
	}
	
	static int[] blockSizes	= {32}; //{4, 8, 16, 32};
	//static int[] quantizations = {0, 1, 2, 4, 8};
	//static double[] gammas		= {0, 0.1, 0.25, 0.5, 1, 3, 5};
	//static int[] quantizations = {1, 2, 4, 8};
	//static double[] gammas		= {0};
	static int[] quantizations = {0};
	static double[] gammas = {0.1, 0.25, 0.5, 1, 3, 5};
	

	
	public static void multiTest() {
		
		for (int bs: blockSizes) {
			for (int q: quantizations) {
				for (double g: gammas) {
					System.out.println("BS,Q,G: " + bs + "," + q + "," + g);
					argsComparison[1] = Integer.toString(q);
					argsComparison[3] = Double.toString(g);
					argsComparison[5] = Integer.toString(bs);
					argsComparison[6] = Integer.toString(bs);
					Main.main(argsComparison);
					System.out.println();
				}
			}
		}
		
	}
}
