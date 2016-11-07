#!/usr/bin/env python
# Copyright (c) PLUMgrid, Inc.
# Licensed under the Apache License, Version 2.0 (the "License")

from pyroute2 import netns
from builtins import input
from http.server import HTTPServer, SimpleHTTPRequestHandler
from netaddr import IPNetwork
from os import chdir
from pyroute2 import IPRoute, NetNS, IPDB, NSPopen
from random import choice, randint
from socket import htons
from threading import Thread
import sys

# Setup -- do before running this script
# rm -rf chord-transitions; git clone https://github.com/iovisor/chord-transitions.git ; cd chord-transitions ; export PATH=node_modules/.bin:$PATH ; npm install bower;  bower install 

def serve_http():
    chdir("chord-transitions")
    # comment below line to see http server log messages
    # SimpleHTTPRequestHandler.log_message = lambda self, format, *args: None
    srv = HTTPServer(("", 8080), SimpleHTTPRequestHandler)
    t = Thread(target=srv.serve_forever)
    t.setDaemon(True)
    t.start()
    print("HTTPServer listening on 0.0.0.0:8080")

try:
    serve_http()
    input("Press enter to quit:")
finally:
    print("done")