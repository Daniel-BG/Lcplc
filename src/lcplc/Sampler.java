package lcplc;

import java.io.BufferedWriter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.List;

public class Sampler <T> {
	
	private List<T> samples;
	
	public Sampler() {
		samples = new ArrayList<T>();
	}
	
	public void sample(T t) {
		samples.add(t);
	}

	public void export(String filename) throws IOException {
		FileOutputStream fos = new FileOutputStream(filename);
		OutputStreamWriter osw = new OutputStreamWriter(fos);
		BufferedWriter bw = new BufferedWriter(osw);
		for (T s: samples) {
			bw.write(s.toString());
			bw.newLine();
		}	
		bw.close();
	}
}


