// Copyright 2013-2016 Apcera Inc. All rights reserved.

package main

import (
	"net"
	"strings"
	"testing"

	. "github.com/apcera/continuum/util/testtool"
)

func TestOVSv1DriverState(t *testing.T) {
	testhelper := StartTest(t)
	defer testhelper.FinishTest()

	state := &ovsv1DriverState{
		portAllocationMap: make(map[int]bool),
	}

	var err error
	ITERATION_COUNT := 100
	portarray := make([]int, ITERATION_COUNT)

	// allocate 100 random ports
	for i := 0; i < ITERATION_COUNT; i++ {
		portarray[i], err = state.allocatePort()
		TestEqual(t, err, nil)
		TestEqual(t, (portarray[i] >= PORT_RANGE_LOW) && (portarray[i] <= PORT_RANGE_HIGH), true)
	}

	// de-allocate all ports
	for i := 0; i < ITERATION_COUNT; i++ {
		err = state.deallocatePort(portarray[i])
		TestEqual(t, err, nil)
	}

	TestEqual(t, checkempty(state.portAllocationMap), true)

}

func TestOVSv1DriverStateLimits(t *testing.T) {
	testhelper := StartTest(t)
	defer testhelper.FinishTest()

	state := &ovsv1DriverState{
		portAllocationMap: make(map[int]bool),
	}

	var err error

	// let's fill up the allocation map and try to allocate another port
	for i := PORT_RANGE_LOW; i < PORT_RANGE_HIGH; i++ {
		state.portAllocationMap[i] = true
	}
	_, err = state.allocatePort()
	TestEqual(t, strings.Contains(err.Error(), "No more free ports"), true)

}

func checkempty(inmap map[int]bool) bool {
	if len(inmap) == 0 {
		return true
	}
	return false
}

func TestIpToPortMapper(t *testing.T) {
	testhelper := StartTest(t)
	defer testhelper.FinishTest()

	result := ipToPortMapper(net.IPv4(192, 168, 1, 0))
	TestEqual(t, result, 356)

	result = ipToPortMapper(net.IPv4(192, 168, 0, 0))
	TestEqual(t, result, 100)

	result = ipToPortMapper(net.IPv4(192, 168, 254, 0))
	TestEqual(t, result, 65124)

}
