package lcplc;

import java.io.BufferedWriter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.List;

public class Sampler <T> {
	
	private List<T> samples;
	private String filename;
	
	public Sampler(String filename) {
		this.filename = filename;
		samples = new ArrayList<T>();
	}
	
	public void sample(T t) {
		samples.add(t);
	}

	public void export() throws IOException {
		FileOutputStream fos = new FileOutputStream(Sampler.samplePath + this.filename + Sampler.extension, true);
		OutputStreamWriter osw = new OutputStreamWriter(fos);
		BufferedWriter bw = new BufferedWriter(osw);
		for (T s: samples) {
			bw.write(s.toString());
			bw.newLine();
		}	
		bw.close();
	}
	
	private static String samplePath;
	private static String extension;
	
	public static void setSamplePath(String samplePath) {
		Sampler.samplePath = samplePath;
	}
	
	public static void setSampleExt(String ext) {
		Sampler.extension = ext;
	}
	
}


