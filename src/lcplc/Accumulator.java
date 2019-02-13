package lcplc;

import java.util.LinkedList;
import java.util.Queue;

/**
 * Class used to accumulate the last N values sent to it,
 * and to make the total value retrievable in linear time
 * @author Daniel
 *
 */
public class Accumulator {
	
	private int maxSize;
	private long runningSum;
	private int runningCount;
	private Queue<Integer> q;
	
	public Accumulator(int maxSize) {
		this.maxSize = maxSize;
		this.reset();
	}
	
	public void reset() {
		this.q = new LinkedList<Integer>();
		this.runningSum = 0;
		this.runningCount = 0;
	}
	
	public void add(int value) {
		if (this.q.size() == this.maxSize)
			this.runningSum -= this.q.poll();
		else
			this.runningCount++;
		
		this.runningSum += value;
		this.q.add(value);
	}
	
	public long getRunningSum() {
		return this.runningSum;
	}
	
	public int getRunningCount() {
		return this.runningCount;
		/*if (this.runningCount == 0)
			return 0;
		if (this.runningCount <  2)
			return 1;
		if (this.runningCount <  4)
			return 2;
		if (this.runningCount <  8)
			return 4;
		if (this.runningCount < 16)
			return 8;
		if (this.runningCount < 32)
			return 16;
		return this.runningCount;*/
		//return this.maxSize;
	}
	
	
}
