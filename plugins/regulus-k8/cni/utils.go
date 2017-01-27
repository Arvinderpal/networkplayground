package main

import (
	"fmt"
	"math/rand"
	"net"
	"sync"
)

const (
	PORT_RANGE_HIGH = 65000
	PORT_RANGE_LOW  = 1000
)

// ovsv1DriverState contains any state the driver must hold in memory
// Note(awander): The state is lost when the IM process terminates. It must be
// recreated using the IfEntry object in cgroupsContainer.
type ovsv1DriverState struct {
	sync.Mutex
	portAllocationMap map[int]bool // map of allocated/free ovs ports (1000...65000).
}

// allocatePort finds and allocates a free port
func (d *ovsv1DriverState) allocatePort() (int, error) {

	d.Lock()
	defer d.Unlock()
	freePort, err := d.getFreePort()
	if err != nil {
		return -1, err
	}
	d.portAllocationMap[freePort] = true

	return freePort, nil
}

// deallocatePort deallocates a previously allocated port
func (d *ovsv1DriverState) deallocatePort(portnum int) error {

	d.Lock()
	defer d.Unlock()
	if !d.portAllocationMap[portnum] {
		return fmt.Errorf("Error: Free called on port which is not in use %v", portnum)
	}
	// we just delete the entry
	delete(d.portAllocationMap, portnum)

	return nil
}

// getFreePort is a utility method for use by allocatePort()
// Returns a free port from the range PORT_RANGE_LOW ... PORT_RANGE_HIGH
func (d *ovsv1DriverState) getFreePort() (int, error) {
	offset := rand.Intn(PORT_RANGE_HIGH-PORT_RANGE_LOW) + PORT_RANGE_LOW
	if !d.portAllocationMap[offset] {
		d.portAllocationMap[offset] = true
		return offset, nil
	}
	// at this point we can do a linear search for a free port
	for i := PORT_RANGE_LOW; i < PORT_RANGE_HIGH; i++ {
		if !d.portAllocationMap[i] {
			d.portAllocationMap[i] = true
			return i, nil
		}
	}
	return -1, fmt.Errorf("Error: No more free ports avaiable")
}

// ipToPortMapper will convert the lower 16 bits to a port id that we can use in ovs
// TODO(awander): Need a better solution. for certain IPs, we may overflow the port range
// NOTE: we also use this same exact function in our kubelet plugins duirng
// policy rules setup. If you modify one, make sure to change the other as well.
func ipToPortMapper(ip net.IP) int {
	var port int
	ipv4 := ip.To4()
	// we use the lower 16 bits of the IP as the port number in ovs
	// so, *.0.1 will map to 1+100, ...
	// *.1.0 will map to 256+100, *1.1 to 257...
	port = int(ipv4[2])
	port = (port << 8)
	port = port | int(ipv4[3])
	return port + 100
}
