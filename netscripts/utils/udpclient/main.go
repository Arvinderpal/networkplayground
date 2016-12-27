package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"strconv"
	"time"
)

const (
	NUMBER_OF_SAMPLES = 2000
)

var (
	debug   bool
	samples [NUMBER_OF_SAMPLES]time.Duration
)

func main() {

	if len(os.Args) < 3 {
		fmt.Errorf("Usage: <server IP> <server port>")
		os.Exit(1)
	}
	saddr := os.Args[1]
	sport := os.Args[2]

	if len(os.Args) > 3 && os.Args[3] != "" {
		debug = true
	}

	buff := make([]byte, 2048)
	conn, err := net.Dial("udp", saddr+":"+sport)
	if err != nil {
		fmt.Printf("Some error %v", err)
		return
	}

	for i := 0; i < NUMBER_OF_SAMPLES; i++ {
		do_echo(conn, buff, i, "test-data-"+strconv.Itoa(i))
	}

	print_results()

	conn.Close()

}

func do_echo(conn net.Conn, p []byte, i int, data string) {
	defer timeTrack(time.Now(), i, "do_echo")

	fmt.Fprintf(conn, data)
	_, err := bufio.NewReader(conn).Read(p)
	if err != nil {
		fmt.Printf("Some error %v\n", err)
		os.Exit(1)
	}
	if debug {
		fmt.Printf("%s\n", p)
	}

}

func timeTrack(start time.Time, i int, name string) {
	elapsed := time.Since(start)
	samples[i] = elapsed
	// fmt.Printf("%s took %s", name, elapsed)
}

func print_results() {
	max := findSamplesMax()
	min := findSamplesMin()
	avg := findSamplesAvg()

	fmt.Printf("Avg: %s, Max: %s, Min: %s\n", avg, max, min)

}

func findSamplesAvg() time.Duration {

	var sum int64
	for i := 0; i < len(samples); i++ {
		sum = sum + samples[i].Nanoseconds()
	}
	return time.Duration(sum / int64(len(samples)))

}

func findSamplesMax() time.Duration {
	var max int64
	for i := 0; i < len(samples); i++ {
		if samples[i].Nanoseconds() > max {
			max = samples[i].Nanoseconds()
		}
	}
	return time.Duration(max)
}

func findSamplesMin() time.Duration {
	var min int64
	if len(samples) == 0 {
		return time.Duration(0)
	} else {
		min = samples[0].Nanoseconds()
	}
	for i := 0; i < len(samples); i++ {
		if samples[i].Nanoseconds() < min {
			min = samples[i].Nanoseconds()
		}
	}
	return time.Duration(min)
}
