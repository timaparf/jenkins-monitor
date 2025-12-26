import time
import sys
import math

def cpu_intensive_task():
    """Keep CPU busy with calculations"""
    x = 0.0
    for _ in range(1000000):  # Increased iterations
        x += math.sqrt((x + 1) * 3.14159)
        x *= 1.000001  # Added multiplication to increase CPU load
    return x

def main():
    # Allocate ~300MB of memory
    memory_hog = [1.0] * (300 * 1024 * 1024 // 8)  # 8 bytes per float
    
    try:
        print("Starting memory and CPU intensive task...")
        while True:
            # CPU intensive calculation
            result = cpu_intensive_task()
            # Reduced sleep time to increase CPU usage
            time.sleep(0.01)
            
    except KeyboardInterrupt:
        print("\nScript interrupted by user")
        sys.exit(1)

if __name__ == "__main__":
    main()
