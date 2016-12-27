package main

import (
	"fmt"
	"net"
	"os"
	"strconv"
)

func sendResponse(conn *net.UDPConn, addr *net.UDPAddr, data []byte) {
	_, err := conn.WriteToUDP(data, addr)
	if err != nil {
		fmt.Printf("Couldn't send response %v", err)
	}
}

func main() {
	if len(os.Args) < 3 {
		fmt.Errorf("Usage: <server IP> <server port>")
		os.Exit(1)
	}
	saddr := os.Args[1]
	sport, err := strconv.Atoi(os.Args[2])
	if err != nil {
		fmt.Errorf("Invalid Port %s", os.Args[2])
		os.Exit(1)
	}

	p := make([]byte, 2048)
	addr := net.UDPAddr{
		Port: sport,
		IP:   net.ParseIP(saddr),
	}
	ser, err := net.ListenUDP("udp", &addr)
	if err != nil {
		fmt.Printf("Some error %v\n", err)
		return
	}
	fmt.Printf("Listining for connections on %s %s\n", saddr, sport)
	for {
		_, remoteaddr, err := ser.ReadFromUDP(p)
		// fmt.Printf("Read a message from %v %s \n", remoteaddr, p)
		if err != nil {
			fmt.Printf("Some error  %v", err)
			continue
		}
		go sendResponse(ser, remoteaddr, p)
	}
}
